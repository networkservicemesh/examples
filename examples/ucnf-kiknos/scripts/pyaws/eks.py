import re

from shell import run_out


class AwsCluster(object):
    def __init__(self, cluster_name, region):
        self.name = cluster_name
        self.region = region
        self.clusterInfo = self.get_cluster_info()

    def get_security_group_id(self):
        res = run_out("aws", "ec2", "describe-security-groups",
                      "--region", self.region, "--filters",
                      "Name=tag:aws:cloudformation:logical-id,Values=SG",
                      "Name=tag:alpha.eksctl.io/cluster-name,Values=" + self.name)

        sgs = res['SecurityGroups']
        if len(sgs) < 1:
            raise Exception("no security group found for cluster {0} nodegroup".format(self.name))
        return sgs[0]["GroupId"]

    def get_cluster_info(self):
        return run_out("aws", "eks", "describe-cluster", name=self.name, region=self.region, output="json")

    def get_subnets_by_ids(self):
        return run_out("aws", "ec2", "describe-subnets", "--subnet-ids",
                       *self.clusterInfo['cluster']['resourcesVpcConfig']['subnetIds'],
                       region=self.region)

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
