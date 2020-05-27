import argparse
import json

from shell import run_out, run_in
from eks import AwsCluster
from utils import get_current_region, reduce_subnets


def create_ec2(ec2_config, data_file=None):
    if data_file:
        run_in("aws", "ec2", "run-instances",
               "--user-data", "file://{0}".format(data_file),
               "--cli-input-json", **ec2_config)
    else:
        run_in("aws", "ec2", "run-instances",
               "--cli-input-json", ec2_config, )


def generate_ec2_config(name, vpc_id, image_id, key_name, instance_type, availability_zone, subnets=list(),
                        core_count=1, threads_count=2):
    return json.dumps({
                "Monitoring": {
                    "State": "disabled"
                },
                "ProductCodes": [],
                "VpcId": vpc_id,
                "CpuOptions": {
                    "CoreCount": core_count,
                    "ThreadsPerCore": threads_count
                },
                "ImageId": image_id,
                "KeyName": key_name,
                "ClientToken": "",
                "SubnetId": "subnet-00c1dd7ac65e8b7ee",
                "InstanceType": instance_type,
                "NetworkInterfaces": [
                    {
                        "VpcId": vpc_id,
                        "InterfaceType": "interface",
                        "SubnetId": subnet
                    } for subnet in subnets

                ],
                "Placement": {
                    "Tenancy": "default",
                    "GroupName": "",
                    "AvailabilityZone": availability_zone
                }
            })


def main():
    parser = argparse.ArgumentParser(description='Utility for dealing with AWS EC2 instances')
    parser.add_argument('--name', required=True,
                        help='EC2 instance name')
    parser.add_argument('--region', required=False,
                        help='Member cluster region')
    parser.add_argument('--ref', required=True,
                        help='Reference to another AWS deployment, so the instance can be linked in the VPC')
    parser.add_argument('--test', required=False,
                        help='Dump generated config', action='store_true')
    parser.add_argument('--open-sg', required=False,
                        help='Open all ports and all ips for SecurityGroups', dest='open_sg', action='store_true')
    parser.add_argument('--availability-zone', required=True,
                        help='Select availability zone. If not provided first will be chosen')

    args = parser.parse_args()

    region = args.region if args.region else get_current_region()

    reference_cluster = AwsCluster(args.ref, region)
    priv_subnets = reference_cluster.get_subnets("Private")
    pub_subnets = reference_cluster.get_subnets("Public")
    vpcid = reference_cluster.get_vpcid()

    subnets = list()
    subnets.append(reduce_subnets(priv_subnets)[args.availability_zone]["id"] if args.availability_zone \
                       else reduce_subnets(priv_subnets).values()[0]["id"])
    subnets.append(reduce_subnets(pub_subnets)[args.availability_zone]["id"] if args.availability_zone \
                       else reduce_subnets(pub_subnets).values()[0]["id"])
    print(args.availability_zone)
    print(subnets)

    cfg = generate_ec2_config(args.name, vpcid, "ami-0fe62e1a9161ec45e", "mihai-asa", "c4.large", args.availability_zone,
                        subnets=subnets)
    create_ec2(cfg, "/home/mihai/pem/day0.txt")

if __name__ == '__main__':
    main()
