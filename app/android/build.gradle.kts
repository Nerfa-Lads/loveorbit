allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildDir = rootProject.layout.buildDirectory.dir("../build")
rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(name))
}

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
