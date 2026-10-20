import subprocess
import os

ff = r"C:\Users\Huri_\AppData\Local\ffmpeg_bin\ffmpeg.exe"
vol10 = r"E:\Respaldo\Cantos\CON TODO MI SER 10"

# Let's inspect tracks 1 to 5 with astats or aspectralstats filter to see frequencies!
for i in range(1, 6):
    f = os.path.join(vol10, f"{i:02d} Pista {i:02d}.mp3")
    cmd = [ff, "-i", f, "-af", "astats=metadata=1:reset=1", "-f", "null", "-"]
    res = subprocess.run(cmd, stderr=subprocess.PIPE, text=True, errors="ignore")
    # print peak levels
    lines = [l for l in res.stderr.splitlines() if "Peak level" in l or "RMS level" in l or "Flat factor" in l]
    print(f"Pista {i:02d}:", lines[:2] if lines else "no stats")
