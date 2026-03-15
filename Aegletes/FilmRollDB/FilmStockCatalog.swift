//
//  FilmStockCatalog.swift
//  Aegletes
//
//  Centralized catalog of film manufacturers, stocks, and known attributes.
//

import Foundation

/// Static catalog of known film stocks and their attributes.
/// Uses simple hard-coded tables (no new model types).
enum FilmStockCatalog {

    // MARK: - Manufacturer & Stock Lists (for pickers)

    static let manufacturerOptions: [String] = [
        "Kodak",
        "Ilford",
        "Cinestill",
        "Fuji",
        "Lomography",
        "Foma",
        "Harman"
    ]

    /// Common film stocks per manufacturer (powers the Stock picker).
    static let stockCatalog: [String: [String]] = [
        "Kodak": [
            "Portra 160",
            "Portra 400",
            "Portra 800",
            "Ektar 100",
            "Gold 200",
            "Ultramax 400",
            "ColorPlus 200",
            "Tri-X 400",
            "T-Max 100",
            "T-Max 400",
            "Ektachrome E100"
        ],
        "Ilford": [
            "HP5+ 400",
            "FP4+ 125",
            "Delta 100",
            "Delta 400",
            "Delta 3200",
            "Pan F 50",
            "XP2 Super 400"
        ],
        "Cinestill": [
            "800T",
            "400D",
            "50D",
            "BwXX"
        ],
        "Fuji": [
            "Superia X-TRA 400",
            "Superia 200",
            "C200",
            "Pro 400H",
            "Velvia 50",
            "Velvia 100",
            "Provia 100F",
            "Neopan Acros 100 II"
        ],
        "Lomography": [
            "Color Negative 100",
            "Color Negative 400",
            "Color Negative 800",
            "LomoChrome Purple",
            "LomoChrome Metropolis",
            "LomoChrome Turquoise"
        ],
        "Foma": [
            "Fomapan 100",
            "Fomapan 200",
            "Fomapan 400"
        ],
        "Harman": [
            "Phoenix I",
            "Phoenix II",
            "Red 125",
            "Switch Azure"
        ]
    ]

    // MARK: - Known Attributes for Specific Stocks

    /// Hard-coded attributes for well-known stocks: (FilmType, box ISO).
    /// Key format: "Manufacturer|Stock"
    static let stockDefaults: [String: (FilmType, Double)] = [
        // Kodak – Portra family
        "Kodak|Portra 160":      (.color, 160),
        "Kodak|Portra 400":      (.color, 400),
        "Kodak|Portra 800":      (.color, 800),

        // Kodak color negative
        "Kodak|Ektar 100":       (.color, 100),
        "Kodak|Gold 200":        (.color, 200),
        "Kodak|Ultramax 400":    (.color, 400),
        "Kodak|ColorPlus 200":   (.color, 200),

        // Kodak B&W
        "Kodak|Tri-X 400":       (.bw,    400),
        "Kodak|T-Max 100":       (.bw,    100),
        "Kodak|T-Max 400":       (.bw,    400),

        // Kodak slide
        "Kodak|Ektachrome E100": (.slide, 100),

        // Ilford B&W
        "Ilford|HP5+ 400":       (.bw, 400),
        "Ilford|FP4+ 125":       (.bw, 125),
        "Ilford|Delta 100":      (.bw, 100),
        "Ilford|Delta 400":      (.bw, 400),
        "Ilford|Delta 3200":     (.bw, 3200),
        "Ilford|Pan F 50":       (.bw, 50),
        "Ilford|XP2 Super 400":  (.bw, 400)

        /// **Extend with Fuji / Cinestill / Lomography / Foma / Harman**
    ]

    /// Look up default film type + box ISO for a given manufacturer + stock.
    static func defaults(
        forManufacturer manufacturer: String,
        stock: String
    ) -> (FilmType, Double)? {
        let m = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = stock.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty, !s.isEmpty else { return nil }
        return stockDefaults["\(m)|\(s)"]
    }
}
