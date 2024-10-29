//
//  ReadData.swift
//  SpatialPlayer
//
//  Created by Alvaro Velad Galvan on 9/4/24.
//

import Foundation


class ReadData: ObservableObject  {
    @Published var videos = [Video]()
        
    init(){
        loadData()
    }
    
    func loadData()  {
        guard let url = Bundle.main.url(forResource: "Videos", withExtension: "json")
            else {
                print("Json file not found")
                return
            }
        
        let data = try? Data(contentsOf: url)
        let videos = try? JSONDecoder().decode([Video].self, from: data!)
        self.videos = videos!
    }
}
