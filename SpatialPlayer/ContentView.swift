//
//  ContentView.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @ObservedObject var datas = ReadData()
    
    @State private var urlDialog = false
    @State private var urlString = "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"
    
    func urlSubmit() {
        if (urlString != "") {
            viewModel.videoURL = URL(string: urlString)
            viewModel.certificateURL = nil
            viewModel.licenseURL = nil
            viewModel.isHLS = false
            viewModel.isDocumentPickerPresented = false
            viewModel.isImmersiveSpaceShown = true
        }
        urlDialog = false
    }
    
    var body: some View {
        VStack {
            if viewModel.isImmersiveSpaceShown {
                if viewModel.isHLS {
                    Text("\(viewModel.videoURL?.absoluteString ?? "")")
                        .bold()
                        .padding()
                    Text("Size:").bold() + Text(" \(viewModel.sizeString)")
                } else {
                    Text("\(viewModel.videoURL?.lastPathComponent ?? "")")
                        .bold()
                        .padding()
                    Text("Spatial:").bold() + Text(" \(viewModel.videoInfo.isSpatial ? "Yes" : "No")")
                    Text("Size:").bold() + Text(" \(viewModel.sizeString)")
                    Text("Projection:").bold() + Text(" \(viewModel.videoInfo.projectionTypeString)")
                    Text("Horizontal FOV:").bold() + Text(" \(viewModel.videoInfo.horizontalFieldOfViewString)")
                    Toggle("Show in stereo", isOn: $viewModel.shouldPlayInStereo)
                        .fixedSize()
                        .disabled(!viewModel.isSpatialVideoAvailable)
                }
                Button("Toggle Play/Pause", action: {
                    if (viewModel.player.timeControlStatus == .playing) {
                        viewModel.player.pause()
                    } else {
                        viewModel.player.play()
                    }
                })
                    .padding()
            } else {
                Text("Spatial Player").font(.title).padding()
                Text("by Michael Swanson (modified by ATEME)")
                Link("https://blog.mikeswanson.com/spatial", destination: URL(string: "https://blog.mikeswanson.com/spatial")!)
                Text("An example spatial video player for MV-HEVC video.\nIt doesn't do much, but I hope it gets you started.\nIf you build something with it, let me know!").padding()
            }
            Button("Select Video", systemImage: "video.fill") {
                viewModel.isImmersiveSpaceShown = false
                viewModel.isDocumentPickerPresented = true
            }
            .padding()
            .sheet(isPresented: $viewModel.isDocumentPickerPresented) {
                DocumentPicker()
            }
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(datas.videos, id: \.id) { video in
                        Button("\(video.name)", action: {
                            if (viewModel.isImmersiveSpaceShown) {
                                viewModel.isImmersiveSpaceShown = false
                                Task {
                                    try? await Task.sleep(nanoseconds:1_000_000_000)
                                    viewModel.videoURL = URL(string: video.url)
                                    viewModel.certificateURL = URL(string: video.certificate ?? "")
                                    viewModel.licenseURL = URL(string: video.license ?? "")
                                    viewModel.isHLS = false
                                    viewModel.isDocumentPickerPresented = false
                                    viewModel.isImmersiveSpaceShown = true
                                }
                            } else {
                                viewModel.videoURL = URL(string: video.url)
                                viewModel.certificateURL = URL(string: video.certificate ?? "")
                                viewModel.licenseURL = URL(string: video.license ?? "")
                                viewModel.isHLS = false
                                viewModel.isDocumentPickerPresented = false
                                viewModel.isImmersiveSpaceShown = true
                            }
                        })
                    }
                        .listStyle(.plain)
                    Button("Enter your URL") {
                        viewModel.isImmersiveSpaceShown = false
                        urlDialog.toggle()
                    }
                    .alert("Enter your URL", isPresented: $urlDialog) {
                        TextField("Enter your URL", text: $urlString)
                        Button("OK", action: urlSubmit)
                    }
                }
            }
                .frame(height: 60)
                .padding()
            Text("Default projection type")
            Picker("Default projection type", selection: $viewModel.defaultProjectionType) {
                ForEach(PlayerViewModel.ProjectionType.allCases) { projectionType in
                    Text(projectionType.rawValue.capitalized)
                }
            }
            Text("Default horizontal field of view")
            Picker("Default horizontal field of view", selection: $viewModel.defaultHorizontalFieldOfView) {
                ForEach(PlayerViewModel.HorizontalFieldOfView.allCases) { horizontalFieldOfView in
                    Text(horizontalFieldOfView.rawValue.capitalized)
                }
            }
            Toggle("Default is spatial", isOn: $viewModel.defaultIsSpatial)
                .fixedSize()
                .padding()
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .onChange(of: viewModel.isImmersiveSpaceShown) { _, newValue in
            Task {
                if newValue {
                    switch await openImmersiveSpace(id: "PlayerImmersiveSpace") {
                    case .opened:
                        viewModel.isImmersiveSpaceShown = true
                    default:
                        viewModel.isImmersiveSpaceShown = false
                    }
                } else {
                    await dismissImmersiveSpace()
                    viewModel.isImmersiveSpaceShown = false
                }
            }
        }
        .onChange(of: viewModel.defaultProjectionType) { _, newValue in
            Task {
                if (viewModel.isHLS) {
                    viewModel.isImmersiveSpaceShown = !viewModel.isImmersiveSpaceShown
                    try? await Task.sleep(nanoseconds:500_000_000)
                    viewModel.isImmersiveSpaceShown = !viewModel.isImmersiveSpaceShown
                }
            }
        }
        .onChange(of: viewModel.defaultHorizontalFieldOfView) { _, newValue in
            Task {
                if (viewModel.isHLS) {
                    viewModel.isImmersiveSpaceShown = !viewModel.isImmersiveSpaceShown
                    try? await Task.sleep(nanoseconds:500_000_000)
                    viewModel.isImmersiveSpaceShown = !viewModel.isImmersiveSpaceShown
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PlayerViewModel())
    }
}
