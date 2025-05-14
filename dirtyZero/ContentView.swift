//
//  ContentView.swift
//  dirtyZero
//
//  Created by Skadz on 5/8/25.
//

import SwiftUI
import DeviceKit
import notify

struct ZeroTweak: Identifiable, Codable {
    var id: String { name }
    var icon: String
    var name: String
    var paths: [String]
    
    enum CodingKeys: String, CodingKey {
        case icon, name, paths
    }
}

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

var tweaks: [ZeroTweak] = [
    ZeroTweak(icon: "dock.rectangle", name: "Dock", paths: ["/System/Library/PrivateFrameworks/CoreMaterial.framework/dockDark.materialrecipe", "/System/Library/PrivateFrameworks/CoreMaterial.framework/dockLight.materialrecipe"]),
    ZeroTweak(icon: "line.3.horizontal", name: "Home Bar", paths: ["/System/Library/PrivateFrameworks/MaterialKit.framework/Assets.car"]),
    ZeroTweak(icon: "folder", name: "Folder Backgrounds", paths: ["/System/Library/PrivateFrameworks/SpringBoardHome.framework/folderDark.materialrecipe", "/System/Library/PrivateFrameworks/SpringBoardHome.framework/folderLight.materialrecipe"]),
    ZeroTweak(icon: "bell.badge", name: "Notification Backgrounds", paths: ["/System/Library/PrivateFrameworks/CoreMaterial.framework/platterStrokeLight.visualstyleset", "/System/Library/PrivateFrameworks/CoreMaterial.framework/platterStrokeDark.visualstyleset", "/System/Library/PrivateFrameworks/CoreMaterial.framework/plattersDark.materialrecipe", "/System/Library/PrivateFrameworks/CoreMaterial.framework/platters.materialrecipe"]),
    ZeroTweak(icon: "lock.iphone", name: "Unlock Background", paths: ["/System/Library/PrivateFrameworks/CoverSheet.framework/dashBoardPasscodeBackground.materialrecipe"]),
    ZeroTweak(icon: "iphone.gen3.radiowaves.left.and.right", name: "Haptic Touch Backgrounds", paths: ["/System/Library/PrivateFrameworks/CoreMaterial.framework/platformContentDark.materialrecipe", "/System/Library/PrivateFrameworks/CoreMaterial.framework/platformContentLight.materialrecipe"]),
    ZeroTweak(icon: "battery.100.circle", name: "Battery Graphic (Charging)", paths: ["/System/Library/PrivateFrameworks/CoverSheet.framework/Assets.car"]),
    ZeroTweak(icon: "square.grid.2x2", name: "Control Center Background", paths: ["/System/Library/PrivateFrameworks/CoreMaterial.framework/modulesBackground.materialrecipe"])
]

var FontTweaks: [ZeroTweak] = [
    ZeroTweak(icon: "circle.slash", name: "Remove Emojis", paths: ["/System/Library/Fonts/CoreAddition/AppleColorEmoji-160px.ttc"]),
    ZeroTweak(icon: "h.circle", name: "Helvetica Font", paths: ["/System/Library/Fonts/Core/SFUI.ttf"]),
]

var DangerZone: [ZeroTweak] = [
    ZeroTweak(icon: "questionmark.app", name: "Broken Font", paths: ["/System/Library/Fonts/Core/SFUI.ttf", "/System/Library/Fonts/Core/Helvetica.ttc"]),
    ZeroTweak(icon: "bell.slash", name: "Hide ALL Banners", paths: ["/System/Library/PrivateFrameworks/SpringBoard.framework/BannersAuthorizedBundleIDs.plist"]),
]

struct ContentView: View {
    let device = Device.current
    @AppStorage("enabledTweaks") private var enabledTweakIds: [String] = []
    
    private var allTweaks: [ZeroTweak] {
        tweaks + FontTweaks + DangerZone
    }
    
    private var enabledTweaks: [ZeroTweak] {
        allTweaks.filter { tweak in enabledTweakIds.contains(tweak.id) }
    }
    
    private func isTweakEnabled(_ tweak: ZeroTweak) -> Bool {
        enabledTweakIds.contains(tweak.id)
    }
    
    private func toggleTweak(_ tweak: ZeroTweak) {
        if isTweakEnabled(tweak) {
            enabledTweakIds.removeAll { $0 == tweak.id }
        } else {
            enabledTweakIds.append(tweak.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section(header: HStack {
                        Image(systemName: "terminal")
                        Text("Logs")
                    }) {
                        HStack {
                            Spacer()
                            ZStack {
                                LogView()
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 7)
                                    .frame(width: 340, height: 260)
                            }
                            Spacer()
                        }
                        .onAppear(perform: {
                            print("[*] Welcome to dirtyZero!\n[*] Running on \(device.systemName!) \(device.systemVersion!), \(device.description)")
                        })
                    }
                    
                    Section(
                    header: HStack {
                        Image(systemName: "gear")
                        Text("Actions")
                    },
                    footer: VStack(alignment: .leading) {
                        Text("All tweaks are done in memory, so if something goes wrong, you can force reboot to revert changes.\n\nExploit discovered by Ian Beer of Google Project Zero. Created by the jailbreak.party team.")
                        Text("\nJoin the jailbreak.party discord!")
                            .foregroundColor(.green)
                            .underline()
                            .onTapGesture {
                                if let url = URL(string: "https://discord.gg/XPj66zZ4gT") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                    ) {
                        VStack {
                            Button(action: {
                                var applyingString = "[*] Applying the selected tweaks: "
                                let tweakNames = enabledTweaks.map { $0.name }.joined(separator: ", ")
                                applyingString += tweakNames
                                
                                print(applyingString)
                                
                                for tweak in enabledTweaks {
                                    for path in tweak.paths {
                                        dirtyZeroHide(path: path)
                                    }
                                }
                                
                                print("[*] All tweaks applied successfully!")
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Apply Tweaks")
                                }
                            }
                            .buttonStyle(TintedButton(color: enabledTweaks.isEmpty ? .accent.dark() : .accent, fullWidth: true))
                            .contextMenu {
                                Button {
                                    Alertinator.shared.prompt(title: "Enter Custom Path", placeholder: "Path") { path in
                                        if let _ = path, !path!.isEmpty {
                                            dirtyZeroHide(path: path!)
                                        } else {
                                            Alertinator.shared.alert(title: "Invalid path", body: "Enter a vaild path that can be zeroed out.")
                                        }
                                    }
                                } label: {
                                    Label("Apply Custom Path", systemImage: "terminal")
                                }
                            }
                            .disabled(enabledTweaks.isEmpty)
                            
                            Button(action: {
                                dirtyZeroHide(path: "/System/Library/CoreServices/SpringBoard.app/SpringBoard")
                            }) {
                                HStack {
                                    Image(systemName: "x.circle.fill")
                                    Text("Remove Tweaks")
                                }
                            }
                            .buttonStyle(TintedButton(color: .red, fullWidth: true))
                        }
                    }
                    
                    Section(header: HStack {
                        Image(systemName: "eye.slash")
                        Text("Hide Items")
                    }) {
                        VStack {
                            ForEach(tweaks) { tweak in
                                Button(action: {
                                    Haptic.shared.play(.soft)
                                    toggleTweak(tweak)
                                }) {
                                    HStack {
                                        Image(systemName: tweak.icon)
                                            .frame(width: 24, alignment: .center)
                                        Text(tweak.name)
                                            .lineLimit(1)
                                            .scaledToFit()
                                        Spacer()
                                        if isTweakEnabled(tweak) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.accent)
                                                .imageScale(.medium)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.accent)
                                                .imageScale(.medium)
                                        }
                                    }
                                }
                                .buttonStyle(TintedButton(color: .accent, fullWidth: false))
                            }
                        }
                    }
                    
                    Section(header: HStack {
                        Image(systemName: "character.cursor.ibeam")
                        Text("Fonts")
                    }) {
                        VStack {
                            ForEach(FontTweaks) { tweak in
                                Button(action: {
                                    Haptic.shared.play(.soft)
                                    toggleTweak(tweak)
                                }) {
                                    HStack {
                                        Image(systemName: tweak.icon)
                                            .frame(width: 24, alignment: .center)
                                        Text(tweak.name)
                                            .lineLimit(1)
                                            .scaledToFit()
                                        Spacer()
                                        if isTweakEnabled(tweak) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.accent)
                                                .imageScale(.medium)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.accent)
                                                .imageScale(.medium)
                                        }
                                    }
                                }
                                .buttonStyle(TintedButton(color: .accent, fullWidth: false))
                            }
                        }
                    }
                    
                    Section(header: HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Danger Zone")
                    }, footer: Text("**WARNING:** These features are only meant for fun, and can break features of your device.")) {
                        VStack {
                            ForEach(DangerZone) { tweak in
                                Button(action: {
                                    Haptic.shared.play(.soft)
                                    toggleTweak(tweak)
                                }) {
                                    HStack {
                                        Image(systemName: tweak.icon)
                                            .frame(width: 24, alignment: .center)
                                        Text(tweak.name)
                                            .lineLimit(1)
                                            .scaledToFit()
                                        Spacer()
                                        if isTweakEnabled(tweak) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.accent)
                                                .imageScale(.medium)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.accent)
                                                .imageScale(.medium)
                                        }
                                    }
                                }
                                .buttonStyle(TintedButton(color: .accent, fullWidth: false))
                            }
                        }
                    }
                }
            }
            .navigationTitle("dirtyZero")
        }
    }
    
    func dirtyZeroHide(path: String) {
        let args = ["permasign", path]
        var argv = args.map { strdup($0) }
        
        _ = permasign(Int32(args.count), &argv)
    }
}

// i skidded this stuff from cowabunga, sorry lemin.
struct MaterialView: UIViewRepresentable {
    let material: UIBlurEffect.Style

    init(_ material: UIBlurEffect.Style) {
        self.material = material
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: material))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: material)
    }
}

struct TintedButton: ButtonStyle {
    var color: Color
    var material: UIBlurEffect.Style?
    var fullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            if fullWidth {
                configuration.label
                    .padding(15)
                    .frame(maxWidth: .infinity)
                    .background(material == nil ? AnyView(color.opacity(0.2)) : AnyView(MaterialView(material!)))
                    .cornerRadius(8)
                    .foregroundStyle(color)
            } else {
                configuration.label
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(material == nil ? AnyView(color.opacity(0.2)) : AnyView(MaterialView(material!)))
                    .cornerRadius(8)
                    .foregroundStyle(color)
            }
        }
    }
    
    init(color: Color = .blue, fullWidth: Bool = false) {
        self.color = color
        self.fullWidth = fullWidth
    }
    init(color: Color = .blue, material: UIBlurEffect.Style, fullWidth: Bool = false) {
        self.color = color
        self.material = material
        self.fullWidth = fullWidth
    }
}

#Preview {
    ContentView()
}
