import socket
import json

HOST = '0.0.0.0'  # Listen on all network interfaces
PORT = 921      # You can choose any available port

# The JSON response to send back to the client
response = {
    "Code": 201,
    "Message": "GSPro Player Information",
    "Player": {
        "Handed": "RH",
        "Club": "DR"
    }
}
response_str = json.dumps(response)

def start_server():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, PORT))
        s.listen()
        print(f"Server listening on {HOST}:{PORT}")
        while True:
            conn, addr = s.accept()
            with conn:
                print(f"Connected by {addr}")
                # Receive data (up to 4KB)
                data = conn.recv(4096)
                if not data:
                    continue
                try:
                    # Try to parse the received data as JSON
                    received_json = json.loads(data.decode('utf-8'))
                    print("Received JSON:")
                    print(json.dumps(received_json, indent=4))
                except Exception as e:
                    print("Error parsing JSON:", e)
                    print("Raw data:", data.decode('utf-8'))
                # Send the response JSON back to the client
                conn.sendall(response_str.encode('utf-8'))
                print("Response sent to client\n")

if __name__ == "__main__":
    start_server()
