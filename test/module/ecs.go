package module

import (
	"fmt"
	"testing"
	"time"

	awsSDK "github.com/aws/aws-sdk-go/aws"
	"github.com/likexian/gokit/assert"

	terratestAws "github.com/gruntwork-io/terratest/modules/aws"
	terratestLogger "github.com/gruntwork-io/terratest/modules/logger"
	terratestStructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// https://github.com/gruntwork-io/terratest/blob/master/test/terraform_aws_ecs_example_test.go
func ValidateEcs(t *testing.T, accountRegion, clusterName, serviceName string, serviceCount int64, deploymentTest DeploymentTest) {
	terratestStructure.RunTestStage(t, "validate_ecs", func() {

		// cluster
		cluster := terratestAws.GetEcsCluster(t, accountRegion, clusterName)
		if cluster == nil {
			t.Fatalf("no service")
		}
		assert.Equal(t, awsSDK.Int64Value(cluster.ActiveServicesCount), serviceCount, "amount of services do not match")

		// tasks in service
		service := terratestAws.GetEcsService(t, accountRegion, clusterName, serviceName)
		if service == nil {
			t.Fatalf("no service")
		}
		serviceTaskDesiredCount := awsSDK.Int64Value(service.DesiredCount)
		assert.NotEqual(t, int64(0), serviceTaskDesiredCount, "amount of tasks in service do not match")

		taskDefinition := terratestAws.GetEcsTaskDefinition(t, accountRegion, awsSDK.StringValue(service.TaskDefinition))
		if taskDefinition == nil {
			t.Fatalf("no task definition")
		}
		latestTaskDefinitionArn := taskDefinition.TaskDefinitionArn
		if latestTaskDefinitionArn == nil {
			t.Fatalf("no task definition arn")
		}
		fmt.Printf("\n\nlatestTaskDefinitionArn = %s\n\n", *latestTaskDefinitionArn)

		if len(service.Deployments) == 0 {
			t.Fatalf("no service deployment")
		}
		deployment := service.Deployments[0] // one deployment because no other service update, take the last one otherwise
		assert.Equal(t, awsSDK.Int64Value(deployment.DesiredCount), serviceTaskDesiredCount, "amount of desired tasks in service do not match")

		maxRetries := 5
		if deploymentTest.MaxRetries != nil {
			maxRetries = *deploymentTest.MaxRetries
		}
		sleepBetweenRetries := 30 * time.Second
		if deploymentTest.SleepBetweenRetries != nil {
			sleepBetweenRetries = *deploymentTest.SleepBetweenRetries
		}
		for i := 0; i <= maxRetries; i++ {
			deployment := terratestAws.GetEcsService(t, accountRegion, clusterName, serviceName).Deployments[0]
			terratestLogger.Log(t, fmt.Sprintf(`
		tasks FAILURE:: %d
		tasks RUNNING:: %d
		tasks PENDING:: %d
		tasks DESIRED:: %d
		`, awsSDK.Int64Value(deployment.FailedTasks), awsSDK.Int64Value(deployment.RunningCount), awsSDK.Int64Value(deployment.PendingCount), serviceTaskDesiredCount))
			if awsSDK.Int64Value(deployment.RunningCount) == serviceTaskDesiredCount {
				terratestLogger.Log(t, `'Task deployment successful`)
				break
			}
			if i == maxRetries {
				t.Fatalf(`Task deployment unsuccessful after %d retries`, maxRetries)
			}
			terratestLogger.Log(t, fmt.Sprintf("Sleeping %s...", sleepBetweenRetries))
			time.Sleep(sleepBetweenRetries)
		}
	})
}
