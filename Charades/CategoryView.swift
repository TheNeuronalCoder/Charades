//
//  CategoryView.swift
//  Charades
//
//  Created by Menelik Eyasu on 7/21/24.
//

import SwiftUI
import CoreData

struct CategoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var moc
    @State private var viewModel = ViewModel()

    var body: some View {
        VStack {
            Image(systemName: "xmark")
                .resizable()
                .frame(width: 30, height: 30)
                .onTapGesture { self.dismiss() }

            viewModel.thumbnail
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250)
            Text(viewModel.name)
            Text(viewModel.caption)

            HStack {
                Image(systemName: "minus.circle")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .onTapGesture { viewModel.reduceDuration() }
                Text(viewModel.gameDurationString)
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .onTapGesture { viewModel.addDuration() }
            }

            NavigationLink(destination: GameView(viewModel.gameDuration, viewModel.words)) {
                Text("Play")
            }
        }.navigationBarHidden(true)
         .onAppear { viewModel.loadWords(moc) }
    }

    init() {}
    init(_ data: Category) {
        self.viewModel.populate(data)
    }
}

extension CategoryView {
    @Observable
    class ViewModel {
        var name = "Category"
        var caption = "Example captions."
        var thumbnail = Image("lighthouse")
        var gameDuration: Int = 5 * 60
        var gameDurationString: String {
            String(
                format: "%d:%02d",
                gameDuration / 60,
                gameDuration % 60
            )
        }

        var words: [Word] = []
        var wordFetch = NSFetchRequest<Word>(entityName: "Word")

        func populate(_ category: Category) {
            self.name = category.name ?? "Category"
            self.caption = category.caption ?? "Example caption."
            if let data = category.thumbnail, let image = UIImage(data: data) {
                self.thumbnail = Image(uiImage: image)
            }

            self.wordFetch.predicate = NSPredicate(
                format: "category == %@ AND locale == %@",
                category,
                category.locale ?? "en-US"
            )
        }

        func loadWords(_ moc: NSManagedObjectContext) {
            if let savedData = try? moc.fetch(self.wordFetch) {
                self.words = savedData
            }
        }

        func reduceDuration() {
            if self.gameDuration > 30 {
                self.gameDuration -= 30
            }
        }

        func addDuration() {
            if self.gameDuration < 5 * 60 {
                self.gameDuration += 30
            }
        }
    }
}

#Preview {
    CategoryView()
}
