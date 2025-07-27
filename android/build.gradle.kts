// build.gradle.kts (nivel raíz del proyecto)

plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Redirige la carpeta build fuera del subdirectorio Android, opcional pero limpio
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // ✅ Asigna carpeta build independiente por subproyecto
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ✅ Asegura evaluación del subproyecto :app antes del resto (necesario con algunos plugins como Google Services)
subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Tarea clean para borrar el nuevo directorio build
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
