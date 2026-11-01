import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import org.gradle.api.artifacts.transform.CacheableTransform
import org.gradle.api.artifacts.transform.InputArtifact
import org.gradle.api.artifacts.transform.TransformAction
import org.gradle.api.artifacts.transform.TransformOutputs
import org.gradle.api.artifacts.transform.TransformParameters
import org.gradle.api.attributes.Attribute
import org.gradle.api.artifacts.type.ArtifactTypeDefinition
import org.gradle.api.file.FileSystemLocation
import org.gradle.api.provider.Provider
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity

/**
 * Liftoff 7.6.1 prevents R8 from processing ALL Google Play Services, including
 * AdMob. Newer Liftoff SDKs removed this rule, but require a newer Ads major.
 * Refine only this known rule while retaining the pinned, compatible SDK pair
 * and every other consumer rule. Never change artifacts in the global cache.
 */
@CacheableTransform
abstract class RefineLiftoffKeepRules : TransformAction<TransformParameters.None> {
    @get:InputArtifact
    @get:PathSensitive(PathSensitivity.NAME_ONLY)
    abstract val inputArtifact: Provider<FileSystemLocation>

    override fun transform(outputs: TransformOutputs) {
        val input = inputArtifact.get().asFile
        if (!input.name.endsWith("vungle-ads-7.6.1.aar")) {
            outputs.file(input)
            return
        }
        ZipFile(input).use { archive ->
            val rulesEntry = requireNotNull(archive.getEntry("proguard.txt"))
            val rules = archive.getInputStream(rulesEntry).bufferedReader().use { it.readText() }
            val broadGoogleRule = Regex(
                "(?m)^-keep class com\\.google\\.android\\.gms\\.\\*\\* \\{ \\*; \\}\\r?$"
            )
            check(broadGoogleRule.findAll(rules).count() == 1) {
                "Liftoff consumer rules changed; review the targeted R8 refinement."
            }
            val refined = rules.replace(broadGoogleRule,
                "# Google SDKs supply their own precise consumer rules.")
            val output = outputs.file(input.nameWithoutExtension + "-refined.aar")
            ZipOutputStream(output.outputStream()).use { target ->
                archive.entries().asSequence().forEach { entry ->
                    target.putNextEntry(ZipEntry(entry.name).apply { time = entry.time })
                    if (!entry.isDirectory) {
                        if (entry.name == "proguard.txt") {
                            target.write(refined.toByteArray(Charsets.UTF_8))
                        } else {
                            archive.getInputStream(entry).use { it.copyTo(target) }
                        }
                    }
                    target.closeEntry()
                }
            }
        }
    }
}

val liftoffRulesRefined = Attribute.of("com.lldm.liftoffRulesRefined", Boolean::class.javaObjectType)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        attributesSchema.attribute(liftoffRulesRefined)
        artifactTypes.maybeCreate("aar").attributes.attribute(liftoffRulesRefined, false)
        registerTransform(RefineLiftoffKeepRules::class.java) {
            from.attribute(ArtifactTypeDefinition.ARTIFACT_TYPE_ATTRIBUTE, "aar")
                .attribute(liftoffRulesRefined, false)
            to.attribute(ArtifactTypeDefinition.ARTIFACT_TYPE_ATTRIBUTE, "aar")
                .attribute(liftoffRulesRefined, true)
        }
    }
    configurations.configureEach {
        attributes.attribute(liftoffRulesRefined, true)
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExtension = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExtension != null && androidExtension.namespace == null) {
            androidExtension.namespace = "com.example.${name.replace("-", "_").replace(" ", "_")}"
        }
        androidExtension?.defaultConfig?.externalNativeBuild?.cmake?.arguments?.add(
            "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
