import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: ((UIImage) -> Void)

    func makeUIViewController(context: Context) -> some UIViewController {
        #if targetEnvironment(macCatalyst)
        return context.coordinator.makeMacImagePicker()
        #else
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        return picker
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker
        var onImagePicked: ((UIImage) -> Void)

        init(_ parent: ImagePicker, onImagePicked: @escaping ((UIImage) -> Void)) {
            self.parent = parent
            self.onImagePicked = onImagePicked
        }

        #if targetEnvironment(macCatalyst)
        func makeMacImagePicker() -> UIViewController {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            return picker
        }
        #endif

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { image, error in
                DispatchQueue.main.async {
                    if let uiImage = image as? UIImage {
                        self.parent.image = uiImage
                        self.onImagePicked(uiImage)
                    }
                }
            }
        }
    }
}

#if targetEnvironment(macCatalyst)
extension ImagePicker.Coordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        if let uiImage = info[.originalImage] as? UIImage {
            self.parent.image = uiImage
            self.onImagePicked(uiImage)
        }
    }
}
#endif
