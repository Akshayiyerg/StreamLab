//
//  CatalogService.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-13.
//

import Foundation

enum CatalogError: LocalizedError {
    case badResponse(Int)
    
    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "The server returned an error (\(code)"
        }
    }
}

struct CatalogService {
    static let url = URL(string: "https://raw.githubusercontent.com/Akshayiyerg/StreamLab/main/catalog.json")!
    
    func fetchCatalog() async throws -> [Video] {
        var request = URLRequest(url: Self.url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw CatalogError.badResponse(0)
        }
        guard http.statusCode == 200 else {
            throw CatalogError.badResponse(http.statusCode)
        }
        
        return try JSONDecoder().decode([Video].self, from: data)
    }
}
