import subprocess

def test_tmux():
    # Make a dummy session
    subprocess.run(["tmux", "new-session", "-d", "-s", "test_head", "echo 'Line 1'; echo 'Line 2'; echo 'Line 3'; sleep 10"])
    
    # Try capture-pane to get first 2 lines
    res = subprocess.run(["tmux", "capture-pane", "-p", "-t", "test_head", "-S", "-", "-E", "1"], capture_output=True, text=True)
    print("RES:")
    print(res.stdout)
    
    subprocess.run(["tmux", "kill-session", "-t", "test_head"])

test_tmux()
