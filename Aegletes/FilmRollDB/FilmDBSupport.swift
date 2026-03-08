// FilmDBSupport.swift
// Aegletes
//
// Shared helpers for Film DB UI

import Foundation

// Identifiable key for film stacks used in UI
extension FilmIdentity: Identifiable {
    var id: String {
        "\(manufacturer)|\(stock)|\(filmType.rawValue)|\(format.rawValue)|\(boxISO)"
    }
}
