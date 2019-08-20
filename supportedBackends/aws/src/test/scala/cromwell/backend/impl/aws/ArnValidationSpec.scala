package cromwell.backend.impl.aws

import org.scalatest.{FlatSpecLike, Matchers}
import wom.values.{WomString, WomValue}

class ArnValidationSpec extends FlatSpecLike with Matchers {
  behavior of "ArnValidation"

  it should "correctly identify valid ARNs" in {
    val validArnsAsStrings = List(
      "arn:aws:batch:us-east-1:111122223333:job-queue/HighPriority",
      "arn:aws:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-west-2:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-west-2:123456789012:job-queue:default-a4e50e00-b850-11e9:1",
      "arn:aws:batch:ap-northeast-2:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-gov-west-1:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-gov-west-1:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-west-2:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-west-2:123456789012:default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-gov-west-1:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-gov-west-1:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws-us-gov:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-east-1:123456789012:compute-environment/my-environment",
      "arn:aws:batch:us-east-1:123456789012:job-definition/my-job-definition:1",
      "arn:aws:batch:us-east-1:123456789012:job-queue/my-queue",
      "arn:aws:s3:::my_corporate_bucket/exampleobject.png",
      "arn:aws:elasticbeanstalk:us-east-1:123456789012:environment/My App/MyEnvironment",
      "arn:aws:iam::123456789012:user/David",
      "arn:aws:rds:eu-west-1:123456789012:db:mysql-db",
      "arn:aws:a4b:us-east-1:123456789012:room/7315ffdf0eeb874dc4ab8a546e8b70ec/5f90e5d608b6baa9c88db56654aef158",
      "arn:aws:ecs:us-east-1:123456789012:container-instance/my-cluster/403125b0-555c-4473-86b5-65982db28a6d",
      "arn:aws:resource-groups:us-west-2:123456789012:group/MyExampleGroup/Myfile.png",
      "arn:aws:s3:::my_corporate_bucket/*",
      "arn:aws:s3:::my_corporate_bucket/Development/*",
    )

    val validArns: List[WomValue] = validArnsAsStrings.map(WomString)

    validArns foreach {
      ArnValidation.isValidArn(_) shouldBe true
    }
  }

  it should "correctly identify invalid ARNs" in {
    val invalidArnsAsStrings = List(
      "arn:aws:iam::123456789012:u*",
      "arn:aws:s3::my_corporate_bucket",
      "arn:AWS:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
    )

    val invalidArns: List[WomValue] = invalidArnsAsStrings.map(WomString)

    invalidArns foreach {
      ArnValidation.isValidArn(_) shouldBe false
    }
  }
}
