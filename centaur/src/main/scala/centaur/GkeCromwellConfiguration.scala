package centaur

import java.lang.ProcessBuilder.Redirect

import better.files.File
import com.typesafe.config.Config


case class GkeCromwellConfiguration(dockerTag: String, dockerComposeFile: String, conf: String, logFile: String) extends CromwellConfiguration {
  override def createProcess: CromwellProcess = {
    case class GkeCromwellProcess(override val cromwellConfiguration: GkeCromwellConfiguration) extends CromwellProcess {
      private val startCommand = Array(
        "/bin/bash",
        "-c",
        s"CROMWELL_TAG=$dockerTag CROMWELL_CONFIG=$conf docker-compose -f $dockerComposeFile up -d")

      override def displayString: String = startCommand.mkString(" ")

      override def start(): Unit = {
        val processBuilder = new java.lang.ProcessBuilder()
          .command(startCommand: _*)
          .redirectOutput(Redirect.appendTo(File(logFile).toJava))
          .redirectErrorStream(true)
        processBuilder.start().waitFor()
        ()
      }

      override def stop(): Unit = {
        val command = Array(
          "/bin/bash",
          "-c",
          s"docker-compose -f $dockerComposeFile down"
        )
        val processBuilder = new java.lang.ProcessBuilder()
          .command(command: _*)
          .redirectOutput(Redirect.appendTo(File(logFile).toJava))
          .redirectErrorStream(true)
        processBuilder.start().waitFor()
        ()
      }

      override def isAlive: Boolean = true

      override def logFile: String = cromwellConfiguration.logFile
    }

    GkeCromwellProcess(this)
  }
}


object GkeCromwellConfiguration {
  def apply(conf: Config): CromwellConfiguration = {
    val dockerTag = conf.getString("docker-tag")
    val dockerComposeFile = conf.getString("docker-compose-file")
    val confPath = conf.getString("conf")
    val logPath = conf.getString("log")

    new GkeCromwellConfiguration(dockerTag, dockerComposeFile, confPath, logPath)
  }
}
