from datetime import datetime
import subprocess

DRY_RUN = False

def run(command: str) -> str:
  return subprocess.run(
    command,
    shell=True,
    capture_output=True,
    text=True
  ).stdout.strip()

def version_up(latest_tag):
    parts = latest_tag.split('.')

    latest_yymm = f"{parts[0]}.{parts[1]}"
    current_yymm = datetime.now().strftime("%y.%m")

    if latest_yymm == current_yymm:
      if len(parts) == 3:
        new_minor = int(parts[2]) + 1
      else:
        new_minor = 1
      return f"{current_yymm}.{new_minor}"
    else:
      return current_yymm

# print(version_up("23.02"))    # 24.06
# print(version_up("23.02.5"))  # 24.06
# print(version_up("24.06"))    # 24.06.1
# print(version_up("24.06.1"))  # 24.06.2

now = datetime.now()
YYMM = now.strftime("%y.%m")

latest_tag = run("gh release list --json tagName --jq '.[0] | .tagName'")
print(f'latest tag: {latest_tag}')

new_tag = version_up(latest_tag)
print(f'new tag: {new_tag}')

push_command = f"git tag {new_tag} && git push origin main {new_tag}"
if not DRY_RUN:
  print(run(push_command))
else:
  print(push_command)
