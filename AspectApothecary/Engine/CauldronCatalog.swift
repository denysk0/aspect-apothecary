import Foundation

enum CauldronCatalog {
    static let items: [CauldronItem] = [
        CauldronItem(id: "ember", name: "Banked Ember", blurb: "Still warm.", priceSkint: 4, yield: [("ignis", 3)]),
        CauldronItem(id: "phial-water", name: "Canal Water", blurb: "Brackish.", priceSkint: 4, yield: [("aqua", 3)]),
        CauldronItem(id: "clod", name: "River Clay", blurb: "Heavy and cold.", priceSkint: 4, yield: [("terra", 3)]),
        CauldronItem(id: "bellows", name: "Cracked Bellows", blurb: "Wheezing.", priceSkint: 4, yield: [("aer", 3)]),
        CauldronItem(id: "abacus", name: "Bent Abacus", blurb: "Beads click neatly.", priceSkint: 4, yield: [("ordo", 3)]),
        CauldronItem(id: "ash", name: "Grave Ash", blurb: "Don't breathe in.", priceSkint: 4, yield: [("perditio", 3)]),

        CauldronItem(id: "kettle", name: "Whistling Kettle", blurb: "Boils itself dry.", priceSkint: 9, yield: [("ignis", 2), ("aqua", 2)]),
        CauldronItem(id: "lantern", name: "Storm Lantern", blurb: "Flickers in still air.", priceSkint: 10, yield: [("aer", 2), ("ignis", 2)]),
        CauldronItem(id: "compass", name: "Drunken Compass", blurb: "Never points twice.", priceSkint: 10, yield: [("aer", 2), ("ordo", 2)]),
        CauldronItem(id: "seedbox", name: "Spice Seedbox", blurb: "Smells of far ports.", priceSkint: 11, yield: [("aqua", 2), ("terra", 2)]),

        CauldronItem(id: "reliquary", name: "Sealed Reliquary", blurb: "Hums with old magic.", priceSkint: 22, yield: [("praecantatio", 1), ("vacuos", 1)]),
        CauldronItem(id: "toolkit", name: "Tinker's Toolkit", blurb: "Worn handles.", priceSkint: 20, yield: [("instrumentum", 1), ("ordo", 1)]),
        CauldronItem(id: "carcass", name: "Tanner's Carcass", blurb: "Best not ask.", priceSkint: 18, yield: [("bestia", 1), ("victus", 1)])
    ]

    static func item(id: String) -> CauldronItem? {
        items.first { $0.id == id }
    }
}
