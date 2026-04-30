import shutil
import os

src = "/Users/justalim/.gemini/antigravity/brain/d46c5f88-2c4c-4a6c-bc48-b1b160bddaa3/smartkit_readme_banner_1777584784757.png"
dst_dir = "assets/readme"
dst = os.path.join(dst_dir, "banner.png")

os.makedirs(dst_dir, exist_ok=True)
try:
    shutil.copy2(src, dst)
    print(f"Successfully copied to {dst}")
except Exception as e:
    print(f"Error: {e}")
