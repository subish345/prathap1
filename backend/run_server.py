import os
import socket
import sys
import uvicorn

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

if __name__ == "__main__":
    local_ip = get_local_ip()
    port = 8000
    print("=" * 62)
    print("  🚀 DRIVEPLUS FASTAPI BACKEND SERVER")
    print("=" * 62)
    print(f"  • Listening on:          http://0.0.0.0:{port}")
    print(f"  • Computer / Localhost:  http://127.0.0.1:{port}")
    print(f"  • Phone on Same Wi-Fi:   http://{local_ip}:{port}")
    print(f"  • Android Emulator:      http://10.0.2.2:{port}")
    print(f"  • API Documentation:     http://127.0.0.1:{port}/docs")
    print("=" * 62)
    print("👉 Enter the 'Phone on Same Wi-Fi' address in the mobile app.")
    print("👉 Keep this terminal running while using DrivePlus.")
    print("=" * 62)
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=True)
