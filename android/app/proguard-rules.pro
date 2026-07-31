# mediapipe:tasks-vision bundles a shaded AutoValue/JavaPoet dependency that
# references javax.lang.model.* (annotation-processing-only APIs, not present
# on Android and not reachable at runtime). R8 flags these as missing classes
# during release minification; suppress the warnings rather than keep them.
-dontwarn javax.lang.model.SourceVersion
-dontwarn javax.lang.model.element.Element
-dontwarn javax.lang.model.element.ElementKind
-dontwarn javax.lang.model.type.TypeMirror
-dontwarn javax.lang.model.type.TypeVisitor
-dontwarn javax.lang.model.util.SimpleTypeVisitor8
