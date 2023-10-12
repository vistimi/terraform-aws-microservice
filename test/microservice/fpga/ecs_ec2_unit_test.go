package microservice_test

import (
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
	"github.com/vistimi/terraform-aws-microservice/util"
)

const (
	projectName = "ms" // microservice
	serviceName = "fpga"

	microservicePath = "../../.."
)

var (
	microserviceInformation = testAwsModule.MicroserviceInformation{
		Branch:          "trunk", // TODO: make it flexible for testing other branches
		HealthCheckPath: "/ping",
		Docker: testAwsModule.Docker{
			Registry: &testAwsModule.Registry{
				Name: util.Ptr("pytorch"),
			},
			Repository: testAwsModule.Repository{
				Name: "torchserve",
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
				Port: util.Ptr(8080),
			}),
		},
	}

	deployment = testAwsModule.DeploymentTest{
		MaxRetries: aws.Int(10),
		Endpoints: []testAwsModule.EndpointTest{
			{
				Command:        util.Ptr("curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg && curl -v -X POST <URL>/predictions/densenet161 -T kitten.jpg"),
				ExpectedStatus: 200,
				MaxRetries:     aws.Int(3),
			},
		},
	}
)

// https://docs.aws.amazon.com/elastic-inference/latest/developerguide/ei-dlc-ecs-pytorch.html
// https://docs.aws.amazon.com/deep-learning-containers/latest/devguide/deep-learning-containers-ecs-tutorials-training.html
func Test_Unit_Microservice_FPGA_ECS_EC2_Densenet(t *testing.T) {
	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics)
	serviceNameSuffix := "unique"

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
								"command": []string{
									"apt update; apt install git wget curl -qy",
									"git clone https://github.com/pytorch/serve.git; cd serve; ls examples/image_classifier/densenet_161/; wget https://download.pytorch.org/models/densenet161-8d451a50.pth",
									"torch-model-archiver --model-name densenet161 --version 1.0 --model-file examples/image_classifier/densenet_161/model.py --serialized-file densenet161-8d451a50.pth --handler image_classifier --extra-files examples/image_classifier/index_to_name.json",
									"mkdir -p model_store; mv densenet161.mar model_store/",
									"echo load_models=ALL >> config.properties; echo inference_address=http://0.0.0.0:8080 >> config.properties; echo management_address=http://0.0.0.0:8081 >> config.properties; echo metrics_address=http://0.0.0.0:8082 >> config.properties; echo default_workers_per_model=1 >> config.properties",
									"torchserve --start --ncs --ts-config config.properties --model-store model_store --models densenet161=densenet161.mar",
									"sleep infinity",
								},
								"readonly_root_filesystem": false,
								"user":                     "root",
							},
						},
					},

					"ec2": map[string]any{
						"key_name":       "local",
						"instance_types": []string{"inf1.xlarge"},
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

//those values where found inside the container for inference made by aws, vmargs are not required

// // MXNet
// vmargs=-XX:+UseContainerSupport -XX:InitialRAMPercentage=8.0 -XX:MaxRAMPercentage=10.0 -XX:-UseLargePages -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError
// model_store=/opt/ml/model
// load_models=ALL
// inference_address=http://0.0.0.0:8080
// management_address=http://0.0.0.0:8081
// metrics_address=http://0.0.0.0:8082

//	// Torchserve: in config.properties, then do torchserve --ts-config config.properties
// vmargs=-Xmx128m -XX:-UseLargePages -XX:+UseG1GC -XX:MaxMetaspaceSize=32M -XX:MaxDirectMemorySize=10m -XX:+ExitOnOutOfMemoryError
// load_models=ALL
// inference_address=http://0.0.0.0:8080
// management_address=http://0.0.0.0:8081
// metrics_address=http://0.0.0.0:8082
