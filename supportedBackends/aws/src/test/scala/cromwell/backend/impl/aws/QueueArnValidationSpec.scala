package cromwell.backend.impl.aws

import org.scalatest.{FlatSpecLike, Matchers}
import wom.values.{WomString, WomValue}

class QueueArnValidationSpec extends FlatSpecLike with Matchers {
  behavior of "QueueArnValidation"

  it should "correctly identify valid ARNs" in {
    val validArnsAsStrings = List(
      "arn:aws:batch:us-east-1:111122223333:job-queue/HighPriority",
      "arn:aws:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-gov-west-1:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-gov-west-1:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws-us-gov:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-east-1:123456789012:job-queue/my_queue",
      "arn:aws:batch:us-east-1:123456789012:job-queue/QueueNameWithLengthExactly128CharsLoremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLaboreEtDoloreMag"
    )

    val validArns: List[WomValue] = validArnsAsStrings.map(WomString)

    validArns foreach {
      QueueArnValidation.isValidQueueArn(_) shouldBe true
    }
  }

  it should "correctly identify invalid ARNs" in {
    val invalidArnsAsStrings = List(
      "arn:aws:s3::my_corporate_bucket",
      "arn:AWS:batch:us-west-2:123456789012:job-queue/default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-east-1:123456789012:job-queue/",
      "arn:aws:batch:us-west-2:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws-cn:batch:us-west-2:123456789012:job-queue:default-a4e50e00-b850-11e9",
      "arn:aws:batch:us-east-1:123456789012:compute-environment/my-environment",
      "arn:aws:batch:us-east-1:123456789012:job-definition/my-job-definition",
      "arn:aws:batch:us-east-1:123456789012:job-queue/QueueNameLongerThan128Chars_129CharsActually_LoremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLabore-",
      "arn:aws:batch:::job-queue/tt"
    )

    val invalidArns: List[WomValue] = invalidArnsAsStrings.map(WomString)

    invalidArns foreach {
      QueueArnValidation.isValidQueueArn(_) shouldBe false
    }
  }
}
