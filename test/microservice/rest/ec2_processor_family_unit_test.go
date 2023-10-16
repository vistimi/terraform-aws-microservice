package microservice_test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
	"github.com/vistimi/terraform-aws-microservice/util"
)

var (
	traffics_http = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port: util.Ptr(80),
			}),
		},
	}
)

func Test_Unit_Microservice_Rest_ECS_EC2_ProcessorFamily_None(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics_http)
	serviceNameSuffix := "none"

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
								"name":   "unique",
								"docker": dockerMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								// install systemmd; service example start
								"command": []string{
									"apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost; sleep infinity",
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

			"traffics": trafficsMap,

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
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics_http, name, "")
	})
}

func Test_Unit_Microservice_Rest_ECS_EC2_ProcessorFamily_AMD(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics_http)
	serviceNameSuffix := "amd"

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
								"name":   "unique",
								"docker": dockerMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								// install systemmd; service example start
								"command": []string{
									"apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost; sleep infinity",
								},
								"readonly_root_filesystem": false,
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"t3a.medium"},
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

			"traffics": trafficsMap,

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
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics_http, name, "")
	})
}

func Test_Unit_Microservice_Rest_ECS_EC2_ProcessorFamily_Intel(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics_http)
	serviceNameSuffix := "intel"

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
								"name":   "unique",
								"docker": dockerMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								// install systemmd; service example start
								"command": []string{
									"apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost; sleep infinity",
								},
								"readonly_root_filesystem": false,
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"m6i.large"},
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

			"traffics": trafficsMap,

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
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics_http, name, "")
	})
}

func Test_Unit_Microservice_Rest_ECS_EC2_ProcessorFamily_AwsGraviton(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics_http)
	serviceNameSuffix := "graviton"

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
								"name":   "unique",
								"docker": dockerMap,
								"entrypoint": []string{
									"/bin/bash",
									"-c",
								},
								// install systemmd; service example start
								"command": []string{
									"apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost; sleep infinity",
								},
								"readonly_root_filesystem": false,
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"t4g.medium"},
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

			"traffics": trafficsMap,

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
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics_http, name, "")
	})
}
