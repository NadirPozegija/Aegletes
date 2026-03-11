//
//  FilmRollRowView.swift
//  Aegletes
//
//  Reusable row layout for a single FilmRoll.
//

import SwiftUI

struct FilmRollRowView: View {
    let title: String
    let roll: FilmRoll
    let titleFont: Font

    init(title: String,
         roll: FilmRoll,
         titleFont: Font = .headline) {
        self.title = title
        self.roll = roll
        self.titleFont = titleFont
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(titleFont)

                FilmRollSubheadlineView(roll: roll)
            }
            Spacer()
        }
    }
}
