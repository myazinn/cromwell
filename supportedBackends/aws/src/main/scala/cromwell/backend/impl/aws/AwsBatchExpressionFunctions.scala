/*
 * Copyright 2018 Amazon.com, Inc. or its affiliates.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the copyright holder nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 *  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 *  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 *  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 *  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 *  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 *  IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 */

package cromwell.backend.impl.aws

import cromwell.backend.standard.{StandardExpressionFunctions, StandardExpressionFunctionsParams}
import cromwell.core.io.IoCommandBuilder
import cromwell.filesystems.s3.S3PathBuilder
import cromwell.filesystems.s3.S3PathBuilder.{InvalidS3Path, PossiblyValidRelativeS3Path, ValidFullS3Path}
import cromwell.filesystems.s3.batch.S3BatchCommandBuilder
import org.slf4j.LoggerFactory

class AwsBatchExpressionFunctions(standardParams: StandardExpressionFunctionsParams)
  extends StandardExpressionFunctions(standardParams) {

  val Log = LoggerFactory.getLogger(AwsBatchAsyncBackendJobExecutionActor.getClass)

  override lazy val ioCommandBuilder: IoCommandBuilder = S3BatchCommandBuilder

  override def preMapping(str: String) = {

    Log.info(s"preMapping with parameter $str")

    S3PathBuilder.validatePath(str) match {
      case _: ValidFullS3Path =>
        Log.info(s"ValidFullS3Path with result $str")
        str
      case PossiblyValidRelativeS3Path =>
        val result = callContext.root.resolve(str.stripPrefix("/")).pathAsString
        Log.info(s"PossiblyValidRelativeS3Path with result $result")
        result
      case invalid: InvalidS3Path => throw new IllegalArgumentException(invalid.errorMessage)
    }
  }

  //backendEngineFunctions AwsBatchExpressionFunctions: standardParams DefaultStandardExpressionFunctionsParams(List(cromwell.filesystems.s3.S3PathBuilder@1835403f),CallContext(s3://cromwell-results-full-2/cromwell-execution/cwl_temp_file_9bf75c3b-e305-4748-8e32-95cc046847e4.cwl/9bf75c3b-e305-4748-8e32-95cc046847e4/call-test,StandardPaths(s3://cromwell-results-full-2/cromwell-execution/cwl_temp_file_9bf75c3b-e305-4748-8e32-95cc046847e4.cwl/9bf75c3b-e305-4748-8e32-95cc046847e4/call-test/test-stdout.log,s3://cromwell-results-full-2/cromwell-execution/cwl_temp_file_9bf75c3b-e305-4748-8e32-95cc046847e4.cwl/9bf75c3b-e305-4748-8e32-95cc046847e4/call-test/test-stderr.log),false),Actor[akka://cromwell-system/user/cromwell-service/IoProxy#-494179084],Dispatcher[akka.dispatchers.backend-dispatcher])
  // pathBuilders List(cromwell.filesystems.s3.S3PathBuilder@1835403f)
  // ioCommandBuilder S3BatchCommandBuilder

  override def toString: String = s"AwsBatchExpressionFunctions: standardParams $standardParams \n pathBuilders $pathBuilders \n ioCommandBuilder $ioCommandBuilder"
}
