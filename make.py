import os
import sys
import struct
import subprocess
from glob import glob

def build_boot():
    boot_asm_path = os.path.join('.', 'src', 'boot', 'boot_sector.asm')
    boot_bin_path = os.path.join('.', 'build', 'boot_sector.bin')
    command = f"nasm -fbin -o {boot_bin_path} {boot_asm_path}"
    ret = subprocess.run(command, capture_output=True, shell=True)
    if len(ret.stdout) > 0:
        print(ret.stdout, file=sys.stdout)
    if len(ret.stderr) > 0:
        print(ret.stderr, file=sys.stderr)
    return ret.returncode


def build_main():
    main_asm_path = os.path.join('.', 'src', 'main', 'main.asm')
    main_bin_path = os.path.join('.', 'build', 'main.bin')
    main_folder_path = os.path.join('.', 'src', 'main')
    command = f"nasm -i {main_folder_path} -fbin -o {main_bin_path} {main_asm_path}"
    ret = subprocess.run(command, capture_output=True, shell=True)
    if len(ret.stdout) > 0:
        print(ret.stdout, file=sys.stdout)
    if len(ret.stderr) > 0:
        print(ret.stderr, file=sys.stderr)
    return ret.returncode

def build_disk():
    boot_bin_path = os.path.join('.', 'build', 'boot_sector.bin')
    main_bin_path = os.path.join('.', 'build', 'main.bin')
    disk_img_path = os.path.join('.', 'disk.raw')
    
    boot = b''
    with open(boot_bin_path, 'rb') as boot_bin:
        boot = boot_bin.read()

    with open(disk_img_path, 'wb') as disk:
        disk.write(boot)
        # This blank will hold how many sectors the main program is
        disk.write(b'\0'*512)
        with open(main_bin_path, 'rb') as main_bin:
            main_bin.seek(0, 2) #goto end
            size = main_bin.tell()

            main_bin.seek(0,0) #to beggining

            count = 0
            temp = main_bin.read(512)
            while len(temp) > 0:
                count += 1
                disk.write(temp)
                temp = main_bin.read(512)
            
            rem = size % 512
            if rem != 0:
                # how many bytes until 512byte aligned
                disk.write(b'\0' * (512-rem))

            disk.seek(len(boot), 0)
            disk.write(struct.pack('<I', count))

def clean():
    boot_bin_path = os.path.join('.', 'build', 'boot_sector.bin')
    main_bin_path = os.path.join('.', 'build', 'main.bin')
    disk_img_path = os.path.join('.', 'disk.raw')
    asset_path = os.path.join('.', 'src', 'main', 'assets', '**.ppm.asm')

    subprocess.run(('rm', boot_bin_path))
    subprocess.run(('rm', main_bin_path))
    subprocess.run(('rm', disk_img_path))

    for asset in glob(asset_path):
        subprocess.run(('rm',  asset))
        

if __name__ == '__main__':
    if (len(sys.argv) < 2):
        print("Usage: python3 make.py {build,clean}")
        sys.exit(0)

    if sys.argv[1] == 'build':
        if (build_boot() != 0):
            print("Boot build failed!", file=sys.stderr)
            sys.exit(-1)
        if (build_main() != 0):
            print("Boot main failed!", file=sys.stderr)
            sys.exit(-1) 
        build_disk()
    elif sys.argv[1] == 'clean':
        clean()
    else:
        print("Usage: python3 make.py build/clean")
        sys.exit(0)
        

