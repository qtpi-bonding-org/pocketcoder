/**
 * PocketCoder Image Relay Worker
 *
 * Streams NixOS image from R2 to Linode Images API.
 * Phone sends tiny JSON request — never touches the 300MB image.
 */

interface Env {
  IMAGES: R2Bucket;
  NIXOS_IMAGE_KEY: string;
}

interface UploadRequest {
  linodeToken: string;
  imageLabel?: string;
  region?: string;
}

interface StatusRequest {
  linodeToken: string;
  label: string;
}

const LINODE_API = "https://api.linode.com/v4";
const DEFAULT_LABEL = "pocketcoder-nixos-v1";
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (url.pathname === "/upload-image" && request.method === "POST") {
      return handleUploadImage(request, env, ctx);
    }

    if (url.pathname === "/image-status" && request.method === "GET") {
      return handleImageStatus(request, env);
    }

    if (url.pathname === "/health") {
      return json({ status: "ok" });
    }

    return json({ error: "Not found" }, 404);
  },
};

async function handleUploadImage(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const body = (await request.json()) as UploadRequest;
  if (!body.linodeToken) {
    return json({ error: "linodeToken is required" }, 400);
  }

  const label = body.imageLabel || DEFAULT_LABEL;
  const region = body.region || "us-east";

  // Check if image already exists
  const existing = await findImageByLabel(body.linodeToken, label);
  if (existing) {
    return json({ imageId: existing.id, status: existing.status, existed: true });
  }

  // Get image size from R2 for the Linode upload request
  const obj = await env.IMAGES.head(env.NIXOS_IMAGE_KEY);
  if (!obj) {
    return json({ error: "NixOS image not found in R2" }, 404);
  }

  // Request upload URL from Linode
  const uploadRes = await fetch(`${LINODE_API}/images/upload`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${body.linodeToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      label,
      description: "PocketCoder NixOS server image",
      region,
      cloud_init: true,
    }),
  });

  if (!uploadRes.ok) {
    const err = await uploadRes.text();
    return json({ error: `Linode upload request failed: ${err}` }, uploadRes.status);
  }

  const uploadData = (await uploadRes.json()) as {
    upload_to: string;
    image: { id: string; status: string };
  };

  // Stream image from R2 to Linode in the background
  ctx.waitUntil(streamImageToLinode(env, uploadData.upload_to));

  return json({
    imageId: uploadData.image.id,
    status: "uploading",
    existed: false,
  });
}

async function streamImageToLinode(env: Env, uploadUrl: string): Promise<void> {
  const obj = await env.IMAGES.get(env.NIXOS_IMAGE_KEY);
  if (!obj) {
    console.error("Failed to read image from R2");
    return;
  }

  const res = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": "application/octet-stream" },
    body: obj.body,
  });

  if (!res.ok) {
    console.error(`Linode upload failed: ${res.status} ${await res.text()}`);
  } else {
    console.log("Image upload to Linode completed successfully");
  }
}

async function handleImageStatus(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const token = url.searchParams.get("linodeToken");
  const label = url.searchParams.get("label");

  if (!token || !label) {
    return json({ error: "linodeToken and label are required" }, 400);
  }

  const image = await findImageByLabel(token, label);
  if (image) {
    return json({ exists: true, imageId: image.id, status: image.status });
  }

  return json({ exists: false });
}

async function findImageByLabel(
  token: string,
  label: string
): Promise<{ id: string; status: string } | null> {
  const res = await fetch(`${LINODE_API}/images?page=1&page_size=100`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) return null;

  const data = (await res.json()) as { data: Array<{ id: string; label: string; status: string }> };
  const match = data.data.find(
    (img) => img.id.startsWith("private/") && img.label === label
  );

  return match ? { id: match.id, status: match.status } : null;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
