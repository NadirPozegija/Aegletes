//// FilmRollStatus+Workflow.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/10/26.
// Centralized status workflow and UI mappings for FilmRollStatus.

import Foundation
import SwiftUI

extension FilmRollStatus {

    /// Next status in the roll lifecycle.
    var nextStatus: FilmRollStatus? {
        switch self {
        case .inStorage: return .loaded
        case .loaded:    return .finished
        case .finished:  return .developed
        case .developed: return .scanning
        case .scanning:  return .archived
        case .archived:  return .scanning
        }
    }

    /// SF Symbol shown next to the current status label.
    var statusSymbolName: String? {
        switch self {
        case .inStorage: return "shippingbox.fill"
        case .loaded:    return "camera.circle.fill"
        case .finished:  return "flag.checkered"
        case .developed: return "testtube.2"
        case .scanning:  return "barcode.viewfinder"
        case .archived:  return "film.stack"
        }
    }

    /// SF Symbol used for the “Update Status” swipe/button action.
    var actionSymbolName: String {
        switch self {
        case .inStorage: return "camera.circle.fill"
        case .loaded:    return "flag.checkered"
        case .finished:  return "testtube.2"
        case .developed: return "barcode.viewfinder"
        case .scanning:  return "film.stack"
        case .archived:  return "barcode.viewfinder"
        }
    }

    /// Tint color for the “Update Status” action.
    var actionTintColor: Color {
        switch self {
        case .inStorage: return .yellow
        case .loaded:    return .green
        case .finished:  return .blue
        case .developed: return .indigo
        case .scanning:  return .red
        case .archived:  return .indigo
        }
    }

    /// Primary action title for updating from this status.
    var actionTitle: String {
        switch self {
        case .inStorage: return "Load Roll"
        case .loaded:    return "Mark Finished"
        case .finished:  return "Mark Developed"
        case .developed: return "Mark Scanning"
        case .scanning:  return "Archive Roll"
        case .archived:  return "Mark Scanning"
        }
    }

    /// Confirmation alert message when transitioning *to* this status.
    var transitionPrompt: String {
        switch self {
        case .inStorage:
            return "Return this roll to storage?"
        case .loaded:
            return "Load this roll into a camera?"
        case .finished:
            return "Mark this roll as Finished?"
        case .developed:
            return "Mark this roll as Developed?"
        case .scanning:
            return "Mark this roll as Scanning?"
        case .archived:
            return "Archive this roll?"
        }
    }
}
