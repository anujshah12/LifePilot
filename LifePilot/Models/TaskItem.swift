// TaskItem is a type alias kept for the SwiftData model container registration.
// The actual task models are DayTask (for active day plans) and TemplateTask (for templates).
// This file exists so the model container reference in LifePilotApp.swift compiles.

import Foundation
import SwiftData

typealias TaskItem = DayTask
