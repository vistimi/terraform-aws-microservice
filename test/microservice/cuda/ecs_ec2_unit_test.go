package microservice_test

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
	"github.com/vistimi/terraform-aws-microservice/util"
)

const (
	projectName = "ms" // microservice
	serviceName = "cuda"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/",
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Ecr: &testAwsModule.Ecr{
					Privacy:    "private",
					AccountId:  util.Ptr("763104351884"),
					RegionName: util.Ptr("us-east-1"),
				},
			},
			Repository: testAwsModule.Repository{
				Name: "pytorch-training",
			},
			Image: &testAwsModule.Image{
				// "1.8.1-cpu-py36-ubuntu18.04-v1.7",
				Tag: "1.8.1-gpu-py36-cu111-ubuntu18.04-v1.7",
			},
		},
	}

	traffics = []testAwsModule.Traffic{
		{
			Listener: testAwsModule.TrafficPoint{
				Port:     util.Ptr(80),
				Protocol: util.Ptr("http"),
			},
			Target: util.Ptr(testAwsModule.TrafficPoint{
				Port: util.Ptr(3000),
			}),
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(15),
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_GPU_ECS_EC2_Mnist(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics)
	serviceNameSuffix := "unique"

	name := util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id)

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
								"command": []string{
									"git clone https://github.com/pytorch/examples.git && pip install -r examples/mnist_hogwild/requirements.txt && python3 examples/mnist_hogwild/main.py --epochs 1",
								},
								"readonly_root_filesystem": false,
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       nil,
						"instance_types": []string{"g4dn.xlarge"},
						"os":             "linux",
						"os_version":     "2",

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
		testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics, name, "")
	})
}
