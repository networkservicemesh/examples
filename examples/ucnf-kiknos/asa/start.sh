virt-install \
 --connect=qemu:///system \
 --network network=virbr1,model=virtio \
 --network network=virbr2,model=virtio \
 --network network=virbr3,model=virtio \
 --name=asav \
 --cpu host \
 --arch=x86_64 \
 --machine=pc-1.0 \
 --vcpus=1 \
 --ram=2048 \
 --os-type=linux \
 --noacpi \
 --virt-type=kvm \
 --import \
 --disk path=asav9-12-3-12.qcow2,format=qcow2,device=disk,bus=ide,cache=none \
 --disk path=day0.iso,format=iso,device=cdrom \
 --console pty,target_type=virtio \
 --serial tcp,host=127.0.0.1:4554,mode=bind,protocol=telnet

