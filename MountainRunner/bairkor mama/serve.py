import http.server
import socketserver
import os
import webbrowser

PORT = 8060

class SecureHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Enable COOP and COEP headers required by Godot 4 Web Assembly
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

def main():
    # Change working directory to script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    handler = SecureHTTPRequestHandler
    # Allow reuse of address
    socketserver.TCPServer.allow_reuse_address = True
    
    with socketserver.TCPServer(("", PORT), handler) as httpd:
        url = f"http://localhost:{PORT}"
        print("====================================================")
        print(" Godot Web Runner Server Active")
        print(f" Serving at: {url}")
        print(" Press Ctrl+C in this terminal window to stop server.")
        print("====================================================")
        
        # Automatically open the browser
        webbrowser.open(url)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")

if __name__ == "__main__":
    main()
