allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val rawTag: String = System.getenv("GITHUB_REF_NAME")?.removePrefix("v") ?: ""
val receiptsVersion: String = if (rawTag.isNotEmpty()) {
    rawTag
} else {
    try {
        val process = ProcessBuilder("git", "describe", "--tags", "--always")
            .redirectOutput(ProcessBuilder.Redirect.PIPE)
            .start()
        process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)
        val out = process.inputStream.bufferedReader().readText().trim().removePrefix("v")
        if (out.isNotEmpty()) out else "1.0.0"
    } catch (_: Exception) {
        "1.0.0"
    }
}

extra["receiptsVersion"] = receiptsVersion
extra["receiptsVersionCode"] = try {
    val clean = receiptsVersion.split("-")[0]
    val parts = clean.split(".")
    val major = parts.getOrNull(0)?.toIntOrNull() ?: 1
    val minor = parts.getOrNull(1)?.toIntOrNull() ?: 0
    val patch = parts.getOrNull(2)?.toIntOrNull() ?: 0
    val code = major * 10000 + minor * 100 + patch
    if (code > 0) code else 1
} catch (_: Exception) {
    1
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
