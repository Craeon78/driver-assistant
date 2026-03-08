
import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - FuelProducts

//======================================

  

enum FuelProducts {

    // Petrol (UN 1203, Hazchem 3YE)

    static let p91 = Product(

        code: "P91",

        name: "ULP 91",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    static let p95 = Product(

        code: "P95",

        name: "ULP 95",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    static let p98 = Product(

        code: "P98",

        name: "ULP 98",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    static let e10 = Product(

        code: "E10",

        name: "E10",

        unNumber: 1203,

        hazchemCode: "3YE",

        sgMinValue: 0.710,

        sgMaxValue: 0.750,

        defaultSgValue: 0.724

    )

    // Diesel (treat as combustible/non-placarded for Phase 1)

    static let diesel = Product(

        code: "DSL",

        name: "Diesel",

        unNumber: nil,

        hazchemCode: "— —",

        sgMinValue: 0.810,

        sgMaxValue: 0.855,

        defaultSgValue: 0.835

    )

    static let b100 = Product(

        code: "B100",

        name: "Biodiesel B100",

        unNumber: nil,

        hazchemCode: "— —",

        sgMinValue: 0.860,

        sgMaxValue: 0.900,

        defaultSgValue: 0.880

    )

    static var all: [Product] {

        [p91, p95, p98, e10, diesel, b100]

    }

}
