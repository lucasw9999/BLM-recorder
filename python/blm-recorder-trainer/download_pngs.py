import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# Set the base URL of your web server
BASE_URL = "http://192.168.5.159:8080/"  # Change this to your actual server URL

# Set the folder where images will be saved
DOWNLOAD_FOLDER = "downloaded_images"

# Ensure the download folder exists
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

def get_all_files():
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.93 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
    }

    """ Fetches the directory listing and extracts all file links """
    response = requests.get(BASE_URL, headers=headers)
    
    if response.status_code != 200:
        print(f"Failed to access {BASE_URL}")
        return []

    # Parse the HTML response
    soup = BeautifulSoup(response.text, 'html.parser')

    # Extract all <a> tags with href attributes
    all_files = [urljoin(BASE_URL, a['href']) for a in soup.find_all('a', href=True)]

    return all_files

def download_file(url, folder):
    """ Downloads a file and saves it to the specified folder """
    filename = os.path.join(folder, os.path.basename(url))
    
    response = requests.get(url, stream=True)
    if response.status_code == 200:
        with open(filename, 'wb') as f:
            for chunk in response.iter_content(1024):
                f.write(chunk)
        print(f"Downloaded: {filename}")
    else:
        print(f"Failed to download: {url}")

def main():
    all_files = get_all_files()

    if not all_files:
        print("No files found.")
        return

    print(f"Found {len(all_files)} files. Downloading...")

    for url in all_files:
        download_file(url, DOWNLOAD_FOLDER)

    print("All downloads complete!")

if __name__ == "__main__":
    main()
