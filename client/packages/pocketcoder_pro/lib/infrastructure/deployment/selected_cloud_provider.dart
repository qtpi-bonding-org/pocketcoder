import 'package:flutter_aeroform/domain/models/cloud_provider.dart';

/// PocketCoder currently exposes Linode as its sole production provider.
/// Keeping this choice in one place lets a future provider selector change
/// composition without scattering provider assumptions through cubits.
const selectedCloudProvider = CloudProviderKind.linode;
const pocketCoderHostLabelPrefix = 'provisioned';
