package microservice_test

// import (
// 	"fmt"
// 	"strings"
// 	"testing"

// 	"github.com/gruntwork-io/terratest/modules/terraform"
// 	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
// 	testAwsModule "github.com/vistimi/terraform-aws-microservice/modules"
// 	"github.com/vistimi/terraform-aws-microservice/util"

// 	terratestShell "github.com/gruntwork-io/terratest/modules/shell"
// )

// func Test_Unit_Microservice_Rest_EKS_Fargate_Httpd(t *testing.T) {
// 	bashCode := fmt.Sprintf("echo SOME_VAR=some_value > %s/override.env", microservicePath)
// 	command := terratestShell.Command{
// 		Command: "bash",
// 		Args:    []string{"-c", bashCode},
// 	}
// 	terratestShell.RunCommandAndGetOutput(t, command)

// 	id, tags, trafficsMap, dockerMap := testAwsModule.SetupMicroservice(t, microserviceInformation, traffics)
// 	serviceNameSuffix := "unique"

// 	name := strings.ToLower(util.Format("-", projectName, serviceName, util.GetEnvVariable("AWS_PROFILE_NAME"), id))

// 	options := util.Ptr(terraform.Options{
// 		TerraformDir: microservicePath,
// 		Vars: map[string]interface{}{
// 			"name": name,

// 			"vpc": map[string]any{
// 				"id":       util.GetEnvVariable("VPC_ID"),
// 				"tag_tier": "public",
// 			},

// 			"orchestrator": map[string]any{
// 				"group": map[string]any{
// 					"name": serviceNameSuffix,
// 					"deployment": map[string]any{
// 						"min_size":     1,
// 						"max_size":     1,
// 						"desired_size": 1,

// 						"cpu":    512,
// 						"memory": 1024,

// 						"containers": []map[string]any{
// 							{
// 								"name":   "unique",
// 								"cpu":    512,
// 								"memory": 1024,
// 								"docker": dockerMap,
// "traffics": trafficsMap,
// 								"entrypoint": []string{
// 									"/bin/bash",
// 									"-c",
// 								},
// 								// install systemmd; service example start
// 								"command": []string{
// 									"apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost; sleep infinity",
// 								},
// 								"readonly_root_filesystem": false,
// 							},
// 						},
// 					},

// 					"fargate": map[string]any{
// 						"os":           "linux",
// 						"architecture": "x86_64",

// 						"capacities": []map[string]any{
// 							{
// 								"type": "ON_DEMAND",
// 							},
// 						},
// 					},
// 				},
// 				"ecs": map[string]any{},
// 			},

// 			"route53": map[string]any{
// 				"zones": []map[string]any{
// 					{
// 						"name": fmt.Sprintf("%s.%s", util.GetEnvVariable("DOMAIN_NAME"), util.GetEnvVariable("DOMAIN_SUFFIX")),
// 					},
// 				},
// 				"record": map[string]any{
// 					"prefixes":       []string{"www"},
// 					"subdomain_name": name,
// 				},
// 			},

// 			"bucket_env": map[string]any{
// 				"force_destroy": true,
// 				"versioning":    false,
// 				"file_key":      fmt.Sprintf("%s.env", microserviceInformation.Branch),
// 				"file_path":     "override.env",
// 			},

// 			"tags": tags,
// 		},
// 	})

// 	// defer func() {
// 	// 	if r := recover(); r != nil {
// 	// 		// destroy all resources if panic
// 	// 		terraform.Destroy(t, options)
// 	// 	}
// 	// 	terratestStructure.RunTestStage(t, "cleanup", func() {
// 	// 		terraform.Destroy(t, options)
// 	// 	})
// 	// }()

// 	terratestStructure.RunTestStage(t, "deploy", func() {
// 		terraform.Init(t, options)
// 		terraform.Plan(t, options)
// 		terraform.Apply(t, options)
// 	})
// 	// terratestStructure.RunTestStage(t, "validate", func() {
// 	// 	serviceName := util.Format("-", name, serviceNameSuffix)
// 	// 	testAwsModule.ValidateMicroservice(t, name, deployment, serviceName)
// 	// 	testAwsModule.ValidateRestEndpoints(t, microservicePath, deployment, traffics, name, "")
// 	// })
// }
