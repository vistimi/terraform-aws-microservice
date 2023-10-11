package microservice_test

import (
	"fmt"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/module"
	"github.com/vistimi/terraform-aws-microservice/util"

	terratestShell "github.com/gruntwork-io/terratest/modules/shell"
)

const (
	projectName = "ms" // microservice
	serviceName = "rest"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/",
		Docker: testAwsModule.Docker{
			Repository: testAwsModule.Repository{
				Name: "ubuntu",
			},
			Image: &testAwsModule.Image{
				Tag: "latest",
			},
		},
	}

	traffics = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
			Base: util.Ptr(true),
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(81),
				Protocol: "http",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: "http",
			},
		},
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(443),
				Protocol: "https",
			},
			Target: testAwsModule.TrafficPoint{
				Port:     util.Ptr(3000),
				Protocol: "https",
			},
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(5),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Path:           microserviceInformation.HealthCheckPath,
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_Rest_ECS_EC2_Httpd(t *testing.T) {

	bashCode := fmt.Sprintf("echo SOME_VAR=some_value > %s/override.env", microservicePath)
	command := terratestShell.Command{
		Command: "bash",
		Args:    []string{"-c", bashCode},
	}
	terratestShell.RunCommandAndGetOutput(t, command)

	nameSuffix, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics)
	serviceNameSuffix := "unique"

	name := util.Format("-", projectName, serviceName, nameSuffix)

	options := util.Ptr(terraform.Options{
		TerraformDir: microservicePath,
		Vars: map[string]interface{}{
			"name": name,

			"vpc": map[string]any{
				"id":   util.GetEnvVariable("VPC_ID"),
				"tier": "public",
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
						"instance_types": []string{"t3.small"},
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
		// TODO: test that /etc/ecs/ecs.config is not empty, requires key_name coming from terratest maybe
		serviceName := util.Format("-", name, serviceNameSuffix)
		testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics, name, "")
	})
}
