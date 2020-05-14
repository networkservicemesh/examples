import argparse
import json
import logging
import re
import subprocess
import sys

logging.basicConfig()
LOG = logging.getLogger(__name__)
LOG.setLevel(logging.DEBUG)

DEFAULT_CIDR_BLOCK = "192.168.0.0/16"


def push(mp, key, val):
    mp[key] = val
    return mp


def reduce_subnets(subnets):
    return reduce(lambda cum, sub: push(cum, sub['AvailabilityZone'], {'id': sub['SubnetId']}),
                  subnets, {})


def run_in(*cmd, **data):
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    json.dump(data, p.stdin)
    p.communicate()
    if p.returncode > 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)


def run_out(*cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    data = json.load(p.stdout)
    p.communicate()
    if p.returncode > 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)
    return data


def get_current_region():
    return subprocess.check_output(["aws", "configure", "get", "default.region"]).decode().rstrip()


def create_cluster(data):
    run_in("eksctl", "create", "cluster", "-f", "-", **data)


class AwsCluster(object):
    def __init__(self, cluster_name, region):
        self.name = cluster_name
        self.region = region
        self.clusterInfo = self.get_cluster_info()

    def get_security_group_id(self):
        sgs = self.clusterInfo['cluster']['resourcesVpcConfig']['securityGroupIds']

        if len(sgs) < 1:
            raise Exception("cluster doesn't have any security groups, please make sure that you have active security "
                            "groups enabled on your cluster")
        return sgs[0]

    def get_cluster_info(self):
        return run_out("aws", "eks", "describe-cluster", "--name", self.name, "--region", self.region, "--output",
                       "json")

    def get_subnets_by_ids(self):
        return run_out("aws", "ec2", "describe-subnets", "--region", self.region, "--subnet-ids",
                       *self.clusterInfo['cluster']['resourcesVpcConfig']['subnetIds'])

    def get_vpcid(self):
        return self.clusterInfo['cluster']['resourcesVpcConfig']['vpcId']

    def get_subnets(self, name):
        return reduce(lambda cum, sub:
                      reduce(lambda tag_cum, tag:
                             tag_cum + [sub] if tag['Key'] == "Name" and bool(re.search(name, tag['Value']))
                             else tag_cum,
                             sub['Tags'],
                             []) + cum if sub['Tags'] else cum,
                      self.get_subnets_by_ids()['Subnets'],
                      [])


def generate_cluster_cfg(name, region, cidr, vpcid, private, public):
    return {
        'apiVersion': 'eksctl.io/v1alpha5',
        'kind': 'ClusterConfig',

        'metadata': {
            'name': name,
            'region': region
        },
        'vpc': {
            'cidr': cidr,
            'id': vpcid,
            'subnets': {
                'private': reduce_subnets(private),
                'public': reduce_subnets(public)
            }
        } if private and public and vpcid else {
            'cidr': cidr,
            'nat': {'gateway': 'Single'},
            'clusterEndpoints': {'publicAccess': True, 'privateAccess': True}
        },

        'nodeGroups': [
            {
                'name': 'cnns-member-ng',
                'minSize': 2,
                'maxSize': 2,
                'instancesDistribution': {
                    'maxPrice': 0.093,
                    'instanceTypes': ["t3a.large", "t3.large"],
                    'onDemandBaseCapacity': 0,
                    'onDemandPercentageAboveBaseCapacity': 50,
                    'spotInstancePools': 2
                },
                'ssh': {
                    'publicKeyPath': '~/.ssh/id_rsa.pub'
                },
                'iam': {
                    'withAddonPolicies': {
                        'externalDNS': True
                    }
                }
            }
        ]
    }


def open_security_groups(cluster_name, region):
    res = run_out("aws", "ec2", "describe-security-groups",
                  "--region", region, "--filters",
                  "Name=tag:aws:cloudformation:logical-id,Values=SG",
                  "Name=tag:alpha.eksctl.io/cluster-name,Values=" + cluster_name)

    sg = res['SecurityGroups']
    if len(sg) < 1:
        raise Exception("no security group found for cluster {0} nodegroup".format(cluster_name))

    subprocess.check_call(
        ["aws", "ec2", "authorize-security-group-ingress", "--group-id", sg[0]['GroupId'], "--protocol", "-1",
         "--port", "-1", "--cidr", "0.0.0.0/0", "--region", region])


def main():
    parser = argparse.ArgumentParser(description='Utility for dealing with AWS clusters')
    parser.add_argument('--name', required=True,
                        help='Member cluster name to create config for.')
    parser.add_argument('--region', required=False,
                        help='Member cluster region')
    parser.add_argument('--ref', required=False,
                        help='Reference cluster name (client cluster will use reference clusters vpc when is created)')
    parser.add_argument('--cidr', required=False,
                        help='Client cluster name to create config yaml for.')
    parser.add_argument('--test', required=False,
                        help='Dump generated config', action='store_true')
    parser.add_argument('--open-sg', required=False,
                        help='Open all ports and all ips for SecurityGroups', dest='open_sg', action='store_true')

    args = parser.parse_args()

    cidr = args.cidr if args.cidr else DEFAULT_CIDR_BLOCK
    region = args.region if args.region else get_current_region()

    priv_subnets, pub_subnets, vpcid = None, None, None
    if args.ref:
        reference_cluster = AwsCluster(args.ref, region)
        priv_subnets = reference_cluster.get_subnets("Private")
        pub_subnets = reference_cluster.get_subnets("Public")
        vpcid = reference_cluster.get_vpcid()

    cfg = generate_cluster_cfg(args.name, region, cidr, vpcid, priv_subnets, pub_subnets)
    if args.test:
        json.dump(cfg, sys.stdout, indent=4)
        return

    create_cluster(cfg)
    if args.open_sg:
        open_security_groups(args.name, region)


if __name__ == '__main__':
    main()
