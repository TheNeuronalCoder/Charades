//
//  ContentView.swift
//  Charades
//
//  Created by Menelik Eyasu on 7/20/24.
//

import SwiftUI
import CoreData
import Contentful

struct ContentView: View {
    @Environment(\.managedObjectContext) private var moc

    @State private var viewModel = ViewModel()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Picker("Language", selection: $viewModel.selectedLocale) {
                    ForEach(viewModel.locales, id: \.name) { locale in
                        Text(locale.name).tag(locale.code)
                    }
                }.onChange(of: viewModel.selectedLocale) {
                    viewModel.loadSavedData(
                        context: moc
                    )
                }

                Text("Decks")

                LazyVGrid(columns: viewModel.categoryColumns, spacing: 5) {
                    ForEach(viewModel.categories) { category in
                        let thumbnail = if let data = category.thumbnail, let image = UIImage(data: data) {
                            Image(uiImage: image)
                        } else {
                            Image("lighthouse")
                        }

                        NavigationLink(destination: CategoryView(category).environment(\.managedObjectContext, moc)) {
                            VStack(alignment: .leading) {
                                thumbnail
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 200, alignment: .center)
                                    .clipped()
                                    .cornerRadius(20)
                                Text(category.name ?? "")
                            }
                        }
                    }
                }
            }
        }.onAppear {
            viewModel.updateData(context: moc)
            if viewModel.categories.isEmpty {
                viewModel.loadSavedData(context: moc)
            }
        }
    }
}

extension ContentView {
    struct Locale {
        let name: String
        let code: String
    }

    @Observable
    class ViewModel {
        let categoryColumns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        var loading = true
        var selectedLocale: String = "en-US"
        var locales: [Locale] = [Locale(
            name: "English (United States)",
            code: "en-US"
        )]

        var categories: [Category] = []

        func loadSavedData(context: NSManagedObjectContext) {
            let request = NSFetchRequest<Category>(entityName: "Category")
            request.predicate = NSPredicate(format: "locale == %@", selectedLocale)
            if let savedData = try? context.fetch(request) {
                self.categories = savedData
            }
        }

        func updateData(context: NSManagedObjectContext) {
            if let space = ProcessInfo.processInfo.environment["CONTENTFUL_SPACE_ID"], let token = ProcessInfo.processInfo.environment["CONTENTFUL_ACCESS_TOKEN"] {
                let client = Client(
                    spaceId: space,
                    accessToken: token
                )

                client.fetchLocales { result in
                    var locales = [Locale]()
                    switch result {
                        case .success(let response):
                            for locale in response.items {
                                locales.append(Locale(
                                    name: locale.name,
                                    code: locale.code.stringValue
                                ))
                            }

                        case .failure(_):
                            locales.append(Locale(
                                name: "English (United States)",
                                code: "en-US"
                            ))
                    }

                    self.locales = locales
                    self.fetchData(
                        client: client,
                        context: context
                    )
                }
            }
        }

        func fetchData(
            client: Client,
            context: NSManagedObjectContext
        ) {
            let query = Query.localizeResults(withLocaleCode: "*")
            client.fetchArray(of: Entry.self, matching: query) { result in
                switch result {
                    case .success(let response):
                        _ = try? context.execute(NSBatchDeleteRequest(
                            fetchRequest: NSFetchRequest(entityName: "Category")
                        ))
                        _ = try? context.execute(NSBatchDeleteRequest(
                            fetchRequest: NSFetchRequest(entityName: "Word")
                        ))
                        try? context.save()

                        for entry in response.items {
                            for locale in self.locales {
                                entry.setLocale(withCode: locale.code)

                                let category = Category(context: context)
                                category.locale = locale.code

                                var words = [String]()
                                for (fieldName, value) in entry.fields {
                                    switch fieldName {
                                        case "name":
                                            category.name = value as? String
                                        case "caption":
                                            category.caption = value as? String
                                        case "thumbnail":
                                            self.loadImageData(value as? String) { data in
                                                category.thumbnail = data
                                            }
                                        case "words":
                                            words = value as? [String] ?? []
                                        default: break
                                    }
                                }

                                for wordValue in words {
                                    let word = Word(context: context)
                                    word.locale = locale.code
                                    word.value = wordValue
                                    word.category = category
                                }
                            }
                        }

                        try? context.save()

                    case .failure(let error):
                        print(error.localizedDescription)
                }

                self.loadSavedData(context: context)
            }
        }

        func loadImageData(_ thumbnail: String?, _ onLoad: @escaping (Data?) -> ()) {
            if let thumbnailURL = thumbnail {
                guard let url = URL(string: thumbnailURL) else {
                    onLoad(nil)
                    return
                }

                URLSession.shared.dataTask(with: url) { data, _, _ in
                    onLoad(data)
                }.resume()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
