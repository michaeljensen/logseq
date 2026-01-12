//
//  FolderPicker.swift
//  App
//
//  Created by weihua on 9/29/21.
//

import Capacitor
import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

@objc(FolderPicker)
public class FolderPicker: CAPPlugin, UIDocumentPickerDelegate {

  public var _call: CAPPluginCall?
  private var securityScopedUrls: [URL] = []

  private func stopAccessingScopedResources() {
    for url in securityScopedUrls {
      url.stopAccessingSecurityScopedResource()
    }
    securityScopedUrls.removeAll()
  }

  @objc func pickFolder(_ call: CAPPluginCall) {
    self._call = call

    // Release any previous security scoped URLs before presenting a new picker.
    stopAccessingScopedResources()

    DispatchQueue.main.async { [weak self] in

      let documentPicker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        documentPicker = UIDocumentPickerViewController(
          forOpeningContentTypes: [UTType.folder],
          asCopy: false
        )
      } else {
        documentPicker = UIDocumentPickerViewController(
          documentTypes: [String(kUTTypeFolder)],
          in: UIDocumentPickerMode.open
        )
      }

      // Set the initial directory.

      if let path = call.getString("path") {
        guard let url = URL(string: path) else {
             call.reject("can not parse url")
             return
        }

        print("picked folder url = " + url.path)

        documentPicker.directoryURL = url
      }

      if #available(iOS 15.0, *) {
        documentPicker.shouldShowFileExtensions = true
      }

      documentPicker.allowsMultipleSelection = false
      documentPicker.delegate = self

      documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen

      self?.bridge?.viewController?.present(
        documentPicker,
        animated: true,
        completion: nil
      )
    }
  }

  public func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    var items: [String] = []
    var bookmarks: [String] = []
    var scoped: Bool = false
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)

    for url in urls {
      if url.startAccessingSecurityScopedResource() {
        scoped = true
        securityScopedUrls.append(url)
      }

      if let bookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil) {
        bookmarks.append(bookmark.base64EncodedString())
      }

      items.append(url.absoluteString)
    }

    self._call?.resolve([
      "path": items.first as Any,
      "localDocumentsPath": documentsPath[0] as Any,
      "bookmark": bookmarks.first as Any,
      "securityScoped": scoped
    ])
  }
}
