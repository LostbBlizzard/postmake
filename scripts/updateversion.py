import os
import sys
import subprocess


datestring = subprocess.getoutput("date --rfc-3339=seconds")
githash = subprocess.getoutput("git rev-parse HEAD")

args = sys.argv

name =  args[1]
version = args[2]
targetos = args[3]
targetarch = args[4]

file = open("cmd/postmake/version.yaml","w")
# file:os.write
file.write("name: " + name + "\n")
file.write("version: " + version + "\n")
file.write("githash: " + githash + "\n")
file.write("targetos: " + targetos + "\n")
file.write("targetarch: " + targetarch + "\n")
file.write("builddate: " + datestring + "\n")

file.close()
