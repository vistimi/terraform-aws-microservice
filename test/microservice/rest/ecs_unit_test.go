package microservice_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
	"github.com/vistimi/terraform-aws-microservice/util"

	terratestShell "github.com/gruntwork-io/terratest/modules/shell"
)

var (
	traffics_many_ingress_many_egress = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port: util.Ptr(80),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(81),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port: util.Ptr(81),
			}),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(443),
				Protocol: util.Ptr("https"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: util.Ptr("http"),
			}),
		},
	}
)

func Test_Unit_Microservice_Rest_ECS_Fargate_Httpd(t *testing.T) {
	bashCode := fmt.Sprintf("echo SOME_VAR=some_value > %s/override.env", microservicePath)
	command := terratestShell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratestShell.RunCommandAndGetOutput(t, command)

	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics_many_ingress_many_egress)
	serviceNameSuffix := "sone"

	name := strings.ToLower(util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id))

	options := util.Ptr(terraform.Options{
		TerraformDir: microservicePath,
		Vars: map[string]interface{}{
			"name": name,

			"vpc": map[string]any{
				"id":       util.GetEnvVariable("VPC_ID"),
				"tag_tier": "public",
			},

			"orchestrator": map[string]any{
				"group": map[string]any{
					"name": serviceNameSuffix,
					"deployment": map[string]any{
						"min_size":     1,
						"max_size":     1,
						"desired_size": 1,

						"cpu":    512,
						"memory": 1024,

						"containers": []map[string]any{
							{
								"name":     "cone",
								"cpu":      512,
								"memory":   1024,
								"docker":   dockerMap,
								"traffics": trafficsMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								"command": []string{
									// listen to 80 by default
									// $${VAR} and %%{VAR} is terraform herodoc
									`apt update -q > /dev/null 2>&1; apt install apache2 ufw systemctl curl -yq > /dev/null 2>&1; ufw app list; echo -e 'Listen 81' >> /etc/apache2/ports.conf; echo print /etc/apache2/ports.conf.....; cat /etc/apache2/ports.conf; echo -e '<VirtualHost *:81>\nServerAdmin webmaster@localhost\nDocumentRoot /var/www/html\nErrorLog $${APACHE_LOG_DIR}/error.log\nCustomLog $${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>' >> /etc/apache2/sites-enabled/000-default.conf; echo print /etc/apache2/sites-enabled/000-default.conf.....; cat /etc/apache2/sites-enabled/000-default.conf; systemctl start apache2; echo test localhost:: $(curl -s -o /dev/null -w '%%{http_code}' localhost); echo test localhost:81:: $(curl -s -o /dev/null -w '%%{http_code}' localhost:81); sleep infinity`,
								},
								"readonly_root_filesystem": false,
							},
						},
					},

					"fargate": map[string]any{
						"os":           "linux",
						"architecture": "x86_64",

						"capacities": []map[string]any{
							{
								"type": "ON_DEMAND",
							},
						},
					},
				},
				"ecs": map[string]any{},
			},

			"route53": map[string]any{
				"zones": []map[string]any{
					{
						"name": fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX")),
					},
				},
				"record": map[string]any{
					"prefixes":       []string{"www"},
					"subdomain_name": name,
				},
			},

			"bucket_env": map[string]any{
				"force_destroy": true,
				"versioning":    false,
				"file_key":      fmt.Sprintf("%s.env", microserviceInformation.Branch),
				"file_path":     "override.env",
			},

			"tags": tags,
		},
	})

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratestStructure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.Init(t, options)
		terraform.Plan(t, options)
		terraform.Apply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics_many_ingress_many_egress, name, "")
	})
}

func Test_Unit_Microservice_Rest_ECS_EC2_Httpd(t *testing.T) {
	bashCode := fmt.Sprintf("echo SOME_VAR=some_value > %s/override.env", microservicePath)
	command := terratestShell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratestShell.RunCommandAndGetOutput(t, command)

	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics_many_ingress_many_egress)
	serviceNameSuffix := "sone"

	name := strings.ToLower(util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id))

	options := util.Ptr(terraform.Options{
		TerraformDir: microservicePath,
		Vars: map[string]interface{}{
			"name": name,

			"vpc": map[string]any{
				"id":       util.GetEnvVariable("VPC_ID"),
				"tag_tier": "public",
			},

			"orchestrator": map[string]any{
				"group": map[string]any{
					"name": serviceNameSuffix,
					"deployment": map[string]any{
						"min_size":     1,
						"max_size":     1,
						"desired_size": 1,

						"containers": []map[string]any{
							{
								"name":     "cone",
								"docker":   dockerMap,
								"traffics": trafficsMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								"command": []string{
									// listen to 80 by default
									// $${VAR} and %%{VAR} is terraform herodoc
									`apt update -q > /dev/null 2>&1; apt install apache2 ufw systemctl curl -yq > /dev/null 2>&1; ufw app list; echo -e 'Listen 81' >> /etc/apache2/ports.conf; echo print /etc/apache2/ports.conf.....; cat /etc/apache2/ports.conf; echo -e '<VirtualHost *:81>\nServerAdmin webmaster@localhost\nDocumentRoot /var/www/html\nErrorLog $${APACHE_LOG_DIR}/error.log\nCustomLog $${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>' >> /etc/apache2/sites-enabled/000-default.conf; echo print /etc/apache2/sites-enabled/000-default.conf.....; cat /etc/apache2/sites-enabled/000-default.conf; systemctl start apache2; echo test localhost:: $(curl -s -o /dev/null -w '%%{http_code}' localhost); echo test localhost:81:: $(curl -s -o /dev/null -w '%%{http_code}' localhost:81); sleep infinity`,
								},
								"readonly_root_filesystem": false,
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"t3.medium"},
						"os":             "linux",
						"os_version":     "2023",

						"capacities": []map[string]any{
							{
								"type": "ON_DEMAND",
							},
						},
					},
				},
				"ecs": map[string]any{},
			},

			"route53": map[string]any{
				"zones": []map[string]any{
					{
						"name": fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX")),
					},
				},
				"record": map[string]any{
					"prefixes":       []string{"www"},
					"subdomain_name": name,
				},
			},

			"bucket_env": map[string]any{
				"force_destroy": true,
				"versioning":    false,
				"file_key":      fmt.Sprintf("%s.env", microserviceInformation.Branch),
				"file_path":     "override.env",
			},

			"tags": tags,
		},
	})

	defer func() {
		if r := recover(); r != nil {
			// destroy all resources if panic
			terraform.Destroy(t, options)
		}
		terratestStructure.RunTestStage(t, "cleanup", func() {
			terraform.Destroy(t, options)
		})
	}()

	terratestStructure.RunTestStage(t, "deploy", func() {
		terraform.Init(t, options)
		terraform.Plan(t, options)
		terraform.Apply(t, options)
	})
	terratestStructure.RunTestStage(t, "validate", func() {
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics_many_ingress_many_egress, name, "")
	})
}
