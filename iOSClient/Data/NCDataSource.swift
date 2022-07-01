//
//  NCDataSource.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import NCCommunication

class NCDataSource: NSObject {

    public var metadatasSource: [tableMetadata] = []
    public var metadatasForSection: [NCMetadataForSection] = []

    private var sectionsValue: [String] = []
    private var providers: [NCCSearchProvider]?
    private var searchResults: [NCCSearchResult]?
    private var shares: [tableShare] = []
    private var localFiles: [tableLocalFile] = []

    private var ascending: Bool = true
    private var sort: String = ""
    private var directoryOnTop: Bool = true
    private var favoriteOnTop: Bool = true
    private var filterLivePhoto: Bool = true
    private var groupByField: String = ""

    override init() {
        super.init()
    }

    init(metadatasSource: [tableMetadata], account: String, sort: String? = "none", ascending: Bool? = false, directoryOnTop: Bool? = true, favoriteOnTop: Bool? = true, filterLivePhoto: Bool? = true, groupByField: String = "name", providers: [NCCSearchProvider]? = nil, searchResults: [NCCSearchResult]? = nil) {
        super.init()

        self.metadatasSource = metadatasSource
        self.shares = NCManageDatabase.shared.getTableShares(account: account)
        self.localFiles = NCManageDatabase.shared.getTableLocalFile(account: account)
        self.sort = sort ?? "none"
        self.ascending = ascending ?? false
        self.directoryOnTop = directoryOnTop ?? true
        self.favoriteOnTop = favoriteOnTop ?? true
        self.filterLivePhoto = filterLivePhoto ?? true
        self.groupByField = groupByField
        // unified search
        self.providers = providers
        self.searchResults = searchResults

        createSections()
    }

    // MARK: -

    func clearDataSource() {

        self.metadatasSource.removeAll()
        self.metadatasForSection.removeAll()
        self.sectionsValue.removeAll()
        self.providers = nil
        self.searchResults = nil
        self.shares.removeAll()
        self.localFiles.removeAll()
    }

    func addSection(metadatas: [tableMetadata], searchResult: NCCSearchResult?) {

        for metadata in metadatas {
            self.metadatasSource.append(metadata)
        }

        if let searchResult = searchResult {
            self.searchResults?.append(searchResult)
        }

        createSections()
    }

    internal func createSections() {

        for metadata in metadatasSource {
            // skipped livePhoto
            if filterLivePhoto && metadata.livePhoto && metadata.ext == "mov" {
                continue
            }
            let section = NSLocalizedString(self.getSectionValue(metadata: metadata), comment: "").lowercased().firstUppercased
            if !self.sectionsValue.contains(section) {
                self.sectionsValue.append(section)
            }
        }

        if let providers = self.providers, !providers.isEmpty {
            var sectionsDictionary: [String:Int] = [:]
            for section in self.sectionsValue {
                if let provider = providers.filter({ $0.name.lowercased() == section.lowercased()}).first {
                    sectionsDictionary[section] = provider.order
                }
            }
            self.sectionsValue.removeAll()
            let sectionsDictionarySorted = sectionsDictionary.sorted(by: { $0.value < $1.value } )
            let appName = NSLocalizedString(NCGlobal.shared.appName, comment: "").lowercased().firstUppercased
            for section in sectionsDictionarySorted {
                if section.key == appName {
                    self.sectionsValue.insert(section.key, at: 0)
                } else {
                    self.sectionsValue.append(section.key)
                }
            }
        } else {
            let directory = NSLocalizedString("directory", comment: "").lowercased().firstUppercased
            self.sectionsValue = self.sectionsValue.sorted {
                if directoryOnTop && $0 == directory {
                    return true
                } else if directoryOnTop && $1 == directory {
                    return false
                }
                if self.ascending {
                    return $0 < $1
                } else {
                    return $0 > $1
                }
            }
        }

        for sectionValue in self.sectionsValue {
            if !existsMetadataForSection(sectionValue: sectionValue) {
                print("DATASOURCE: create metadata for section: " + sectionValue)
                createMetadataForSection(sectionValue: sectionValue)
            }
        }
    }

    internal func createMetadataForSection(sectionValue: String) {

        var searchResult: NCCSearchResult?
        if let providers = self.providers, !providers.isEmpty, let searchResults = self.searchResults {
            searchResult = searchResults.filter({ $0.name == sectionValue}).first
        }
        let metadatas = metadatasSource.filter({ getSectionValue(metadata: $0) == sectionValue})
        let metadataForSection = NCMetadataForSection.init(sectionValue: sectionValue,
                                                            metadatas: metadatas,
                                                            shares: self.shares,
                                                            localFiles: self.localFiles,
                                                            searchResult: searchResult,
                                                            sort: self.sort,
                                                            ascending: self.ascending,
                                                            directoryOnTop: self.directoryOnTop,
                                                            favoriteOnTop: self.favoriteOnTop,
                                                            filterLivePhoto: self.filterLivePhoto)
        metadatasForSection.append(metadataForSection)
    }

    // MARK: -

    @discardableResult
    func addMetadata(_ metadata: tableMetadata) -> (indexPath: IndexPath?, sameSections: Bool) {

        let numberOfSections = self.numberOfSections()

        // ADD metadatasSource
        if let rowIndex = self.metadatasSource.firstIndex(where: {$0.fileNameView == metadata.fileNameView || $0.ocId == metadata.ocId}) {
            self.metadatasSource[rowIndex] = metadata
        } else {
            self.metadatasSource.append(metadata)
        }

        // ADD metadataForSection
        if let sectionIndex = self.sectionsValue.firstIndex(where: {$0 == self.getSectionValue(metadata: metadata) }), let metadataForSection = getMetadataForSection(sectionIndex) {
            if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.fileNameView == metadata.fileNameView || $0.ocId == metadata.ocId}) {
                metadataForSection.metadatas[rowIndex] = metadata
                return (IndexPath(row: rowIndex, section: sectionIndex), self.isSameNumbersOfSections(numberOfSections: numberOfSections))
            } else {
                metadataForSection.metadatas.append(metadata)
                metadataForSection.createMetadatasForSection()
                if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.ocId == metadata.ocId}) {
                    return (IndexPath(row: rowIndex, section: sectionIndex), self.isSameNumbersOfSections(numberOfSections: numberOfSections))
                }
                return (nil, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
            }
        } else {
            // NEW section
            createSections()
            let sectionValue = getSectionValue(metadata: metadata)
            createMetadataForSection(sectionValue: sectionValue)
            // get IndexPath of new section
            if let sectionIndex = self.sectionsValue.firstIndex(where: {$0 == sectionValue }), let metadataForSection = getMetadataForSection(sectionIndex) {
                if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.fileNameView == metadata.fileNameView || $0.ocId == metadata.ocId}) {
                    return (IndexPath(row: rowIndex, section: sectionIndex), self.isSameNumbersOfSections(numberOfSections: numberOfSections))
                }
            }
        }

        return (nil, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
    }

    func deleteMetadata(ocId: String) -> (indexPath: IndexPath?, sameSections: Bool) {

        let numberOfSections = self.numberOfSections()
        var indexPathReturn: IndexPath?
        var removeMetadataForSection = false
        var sectionValue = ""

        // DELETE metadataForSection (IMPORTANT FIRST)
        let (indexPath, metadataForSection) = self.getIndexPathMetadata(ocId: ocId)
        if let indexPath = indexPath, let metadataForSection = metadataForSection {
            metadataForSection.metadatas.remove(at: indexPath.row)
            if metadataForSection.metadatas.count == 0 {
                sectionValue = metadataForSection.sectionValue
                removeMetadataForSection = true
            } else {
                metadataForSection.createMetadatasForSection()
            }
            indexPathReturn = indexPath
        }

        // DELETE metadatasSource (IMPORTANT LAST)
        if let rowIndex = self.metadatasSource.firstIndex(where: {$0.ocId == ocId}) {
            self.metadatasSource.remove(at: rowIndex)
        }

        // REMOVE sectionsValue / metadatasForSection
        if removeMetadataForSection {
            if let index = self.sectionsValue.firstIndex(where: {$0 == sectionValue }) {
                self.sectionsValue.remove(at: index)
            }
            if let index = self.metadatasForSection.firstIndex(where: {$0.sectionValue == sectionValue }) {
                self.metadatasForSection.remove(at: index)
            }
        }

        return (indexPathReturn, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
    }

    @discardableResult
    func reloadMetadata(ocId: String, ocIdTemp: String? = nil) -> (indexPath: IndexPath?, sameSections: Bool) {

        let numberOfSections = self.numberOfSections()
        var ocIdSearch = ocId
        var indexPath: IndexPath?
        var metadataForSection: NCMetadataForSection?

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return (nil, self.isSameNumbersOfSections(numberOfSections: numberOfSections)) }

        if let ocIdTemp = ocIdTemp {
            ocIdSearch = ocIdTemp
        }

        // UPDATE metadataForSection (IMPORTANT FIRST)
        (indexPath, metadataForSection) = self.getIndexPathMetadata(ocId: ocIdSearch)
        if let indexPath = indexPath, let metadataForSection = metadataForSection {
            metadataForSection.metadatas[indexPath.row] = metadata
            metadataForSection.createMetadatasForSection()
        }

        // UPDATE metadatasSource (IMPORTANT LAST)
        if let rowIndex = self.metadatasSource.firstIndex(where: {$0.ocId == ocIdSearch}) {
            self.metadatasSource[rowIndex] = metadata
        }

        return (indexPath, self.isSameNumbersOfSections(numberOfSections: numberOfSections))
    }

    // MARK: -

    func getIndexPathMetadata(ocId: String) -> (indexPath: IndexPath?, metadataForSection: NCMetadataForSection?) {

        if let metadata = metadatasSource.filter({ $0.ocId == ocId}).first {
            let sectionValue = getSectionValue(metadata: metadata)
            if let sectionIndex = self.sectionsValue.firstIndex(where: {$0 == sectionValue}) {
                for metadataForSection in self.metadatasForSection {
                    if metadataForSection.sectionValue == sectionValue {
                        if let rowIndex = metadataForSection.metadatas.firstIndex(where: {$0.ocId == ocId}) {
                            return (IndexPath(row: rowIndex, section: sectionIndex), metadataForSection)
                        }
                    }
                }
            }
        }

        return (nil, nil)
    }

    func isSameNumbersOfSections(numberOfSections: Int) -> Bool {
        if self.metadatasForSection.count == 0 { return false }
        return numberOfSections == self.numberOfSections()
    }

    func numberOfSections() -> Int {
        if self.sectionsValue.count == 0 {
            return 1
        } else {
            return self.sectionsValue.count
        }
    }
    
    func numberOfItemsInSection(_ section: Int) -> Int {

        if self.sectionsValue.count == 0 || self.metadatasSource.count == 0 { return 0 }
        if let metadataForSection = getMetadataForSection(section) {
            return metadataForSection.metadatas.count
        } else { return 0 }
    }

    func cellForItemAt(indexPath: IndexPath) -> tableMetadata? {

        if metadatasForSection.count == 0 || indexPath.section >= metadatasForSection.count {
            return nil
        }
        if let metadataForSection = getMetadataForSection(indexPath.section) {
            if indexPath.row >= metadataForSection.metadatas.count {
                return nil
            }
            return metadataForSection.metadatas[indexPath.row]
        } else { return nil }
    }

    func getSectionValue(indexPath: IndexPath) -> String {

        if metadatasForSection.count == 0 { return "" }
        let metadataForSection = self.metadatasForSection[indexPath.section]
        return metadataForSection.sectionValue
    }

    func getFooterInformation() -> (directories: Int, files: Int, size: Int64) {

        var directories: Int = 0
        var files: Int = 0
        var size: Int64 = 0

        for metadataForSection in metadatasForSection {
            directories += metadataForSection.numDirectory
            files += metadataForSection.numFile
            size += metadataForSection.totalSize
        }

        return (directories, files, size)
    }

    func existsMetadataForSection(sectionValue: String) -> Bool {
        for metadataForSection in self.metadatasForSection {
            if metadataForSection.sectionValue == sectionValue {
                return true
            }
        }
        return false
    }

    internal func getSectionValue(metadata: tableMetadata) -> String {

        switch self.groupByField {
        case "name":
            return NSLocalizedString(metadata.name, comment: "").lowercased().firstUppercased
        case "classFile":
            return NSLocalizedString(metadata.classFile, comment: "").lowercased().firstUppercased
        default:
            return NSLocalizedString(metadata.name, comment: "").lowercased().firstUppercased
        }
    }

    internal func getMetadataForSection(_ section: Int) -> NCMetadataForSection? {
        guard section < sectionsValue.count else { return nil }
        let sectionValue = sectionsValue[section]
        if let metadataForSection = self.metadatasForSection.filter({ $0.sectionValue == sectionValue}).first {
            return metadataForSection
        } else { return nil }
    }
}

class NCMetadataForSection: NSObject {

    var sectionValue: String
    var metadatas: [tableMetadata]
    var shares: [tableShare]
    var localFiles: [tableLocalFile]
    var searchResult: NCCSearchResult?
    var unifiedSearchInProgress: Bool = false

    private var sort : String
    private var ascending: Bool
    private var directoryOnTop: Bool
    private var favoriteOnTop: Bool
    private var filterLivePhoto: Bool

    private var metadatasSourceSorted: [tableMetadata] = []
    private var metadatasFavoriteDirectory: [tableMetadata] = []
    private var metadatasFavoriteFile: [tableMetadata] = []
    private var metadatasDirectory: [tableMetadata] = []
    private var metadatasFile: [tableMetadata] = []

    public var numDirectory: Int = 0
    public var numFile: Int = 0
    public var totalSize: Int64 = 0
    public var metadataShare: [String: tableShare] = [:]
    public var metadataOffLine: [String] = []


    init(sectionValue: String, metadatas: [tableMetadata], shares: [tableShare], localFiles: [tableLocalFile], searchResult: NCCSearchResult?, sort: String, ascending: Bool, directoryOnTop: Bool, favoriteOnTop: Bool, filterLivePhoto: Bool) {

        self.sectionValue = sectionValue
        self.metadatas = metadatas
        self.shares = shares
        self.localFiles = localFiles
        self.searchResult = searchResult
        self.sort = sort
        self.ascending = ascending
        self.directoryOnTop = directoryOnTop
        self.favoriteOnTop = favoriteOnTop
        self.filterLivePhoto = filterLivePhoto

        super.init()

        createMetadatasForSection()
    }

    func createMetadatasForSection() {

        // Clear
        //
        metadatasSourceSorted.removeAll()
        metadatasFavoriteDirectory.removeAll()
        metadatasFavoriteFile.removeAll()
        metadatasDirectory.removeAll()
        metadatasFile.removeAll()
        metadataShare.removeAll()
        metadataOffLine.removeAll()

        numDirectory = 0
        numFile = 0
        totalSize = 0

        // Metadata order
        //
        if sort != "none" && sort != "" {
            metadatasSourceSorted = metadatas.sorted {

                switch sort {
                case "date":
                    if ascending {
                        return ($0.date as Date) < ($1.date as Date)
                    } else {
                        return ($0.date as Date) > ($1.date as Date)
                    }
                case "size":
                    if ascending {
                        return $0.size < $1.size
                    } else {
                        return $0.size > $1.size
                    }
                default:
                    if ascending {
                        return $0.fileNameView.lowercased() < $1.fileNameView.lowercased()
                    } else {
                        return $0.fileNameView.lowercased() > $1.fileNameView.lowercased()
                    }
                }
            }
        } else {
            metadatasSourceSorted = metadatas
        }

        // Initialize datasource
        //
        for metadata in metadatasSourceSorted {

            // skipped the root file
            if metadata.fileName == "." || metadata.serverUrl == ".." {
                continue
            }

            // skipped livePhoto
            if filterLivePhoto && metadata.livePhoto && metadata.ext == "mov" {
                continue
            }

            // share
            if let share = self.shares.filter({ $0.serverUrl == metadata.serverUrl && $0.fileName == metadata.fileName }).first {
                metadataShare[metadata.ocId] = share
            }

            // is Local / offline
            if !metadata.directory, CCUtility.fileProviderStorageExists(metadata) {
                let localFile = self.localFiles.filter({ $0.ocId == metadata.ocId }).first
                if localFile == nil {
                    NCManageDatabase.shared.addLocalFile(metadata: metadata)
                }
                if localFile?.offline ?? false {
                    metadataOffLine.append(metadata.ocId)
                }
            }

            // Organized the metadata
            if metadata.favorite && favoriteOnTop {
                if metadata.directory {
                    metadatasFavoriteDirectory.append(metadata)
                } else {
                    metadatasFavoriteFile.append(metadata)
                }
            } else if  metadata.directory && directoryOnTop {
                metadatasDirectory.append(metadata)
            } else {
                metadatasFile.append(metadata)
            }

            //Info
            if metadata.directory {
                numDirectory += 1
            } else {
                numFile += 1
                totalSize += metadata.size
            }
        }

        metadatas.removeAll()

        // Struct view : favorite dir -> favorite file -> directory -> files
        metadatas += metadatasFavoriteDirectory
        metadatas += metadatasFavoriteFile
        metadatas += metadatasDirectory
        metadatas += metadatasFile
    }
}
