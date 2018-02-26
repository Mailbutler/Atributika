//
//  Detection.swift
//  Atributika
//
//  Created by Pavel Sharanda on 21.02.17.
//  Copyright © 2017 psharanda. All rights reserved.
//

import Foundation

public struct Tag {
    public let name: String
    public let attributes: [String: String]
}

public struct TagInfo {
    public let tag: Tag
    public let range: Range<String.Index>
}

public enum TagType {
    case start
    case end
}

public struct TagTransformer {

    public let tagName: String
    public let tagType: TagType
    public let transform: (Tag) -> String
    
    public init(tagName: String, tagType: TagType, replaceValue: String) {
        self.tagName = tagName
        self.tagType = tagType
        self.transform = { _ in replaceValue }
    }
    
    public init(tagName: String, tagType: TagType, transform: @escaping (Tag) -> String) {
        self.tagName = tagName
        self.tagType = tagType
        self.transform = transform
    }
    
    public static var brTransformer: TagTransformer {
        return TagTransformer(tagName: "br", tagType: .start , replaceValue: "\n")
    }
}

extension String {
    
    private func parseTag(_ tagString: String, parseAttributes: Bool) -> Tag? {
        
        let tagScanner = Scanner(string: tagString)
        
        guard let tagName = tagScanner.scanCharacters(from: CharacterSet.alphanumerics) else {
            return nil
        }
        
        var attrubutes = [String: String]()
        
        while parseAttributes && !tagScanner.isAtEnd {
            
            guard let name = tagScanner.scanUpTo("=") else {
                break
            }
            
            guard tagScanner.scanString("=") != nil else {
                break
            }
            
            guard tagScanner.scanString("\"") != nil else {
                break
            }
            
            guard let value = tagScanner.scanUpTo("\"") else {
                break
            }
            
            guard tagScanner.scanString("\"") != nil else {
                break
            }
            
            attrubutes[name] = value.replacingOccurrences(of: "&quot;", with: "\"")
        }
        
        return Tag(name: tagName, attributes: attrubutes)
    }

    public func detectTags(transformers: [TagTransformer] = []) -> (string: String, tagsInfo: [TagInfo]) {
        
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil
        var resultString = String()
        var tagsResult = [TagInfo]()
        var tagsStack = [(Tag, String.Index)]()
        
        while !scanner.isAtEnd {
            
            if let textString = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "<&")) {
                resultString += textString
            } else {
                if scanner.scanString("<") != nil {
                    let tagType = scanner.scanString("/") == nil ? TagType.start : TagType.end
                    if let tagString = scanner.scanUpTo(">") {
                        
                        if let tag = parseTag(tagString, parseAttributes: tagType == .start ) {
                            
                            let resultTextEndIndex = resultString.endIndex
                            
                            if let transformer = transformers.first(where: {
                                $0.tagName == tag.name && $0.tagType == tagType
                            }) {
                                resultString += transformer.transform(tag)
                            }
                            
                            if tagType == .start {
                                tagsStack.append((tag, resultTextEndIndex))
                            } else {
                                for (index, (tagInStack, startIndex)) in tagsStack.enumerated().reversed() {
                                    if tagInStack.name == tag.name {
                                        tagsResult.append(TagInfo(tag: tagInStack, range: startIndex..<resultTextEndIndex))
                                        tagsStack.remove(at: index)
                                        break
                                    }
                                }
                            }
                        }
                        scanner.scanString(">")
                    }
                } else if scanner.scanString("&") != nil {
                    if let specialString = scanner.scanUpTo(";") {
                        if let spec = String.specials[specialString] {
                            resultString += spec
                        }
                        scanner.scanString(";")
                    }
                }
            }
        }
        
        return (resultString, tagsResult)
    }
    
    public func detectHashTags() -> [Range<String.Index>] {
        
        return detect(regex: "[#]\\w\\S*\\b")
    }
    
    public func detectMentions() -> [Range<String.Index>] {
        
        return detect(regex: "[@]\\w\\S*\\b")
    }
    
    public func detect(regex: String, options: NSRegularExpression.Options = []) -> [Range<String.Index>] {
        
        var ranges = [Range<String.Index>]()
        
        let dataDetector = try? NSRegularExpression(pattern: regex, options: options)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = Range(r.range, in: self) {
                ranges.append(range)
            }
        })
        
        return ranges
    }
    
    public func detect(textCheckingTypes: NSTextCheckingResult.CheckingType) -> [Range<String.Index>] {
        
        var ranges = [Range<String.Index>]()
        
        let dataDetector = try? NSDataDetector(types: textCheckingTypes.rawValue)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = Range(r.range, in: self) {
                ranges.append(range)
            }
        })
        return ranges
    }

    // Mapping from XML/HTML character entity reference to character
    private static let specials = [
        // Taken from http://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references
        // Complete refrence here https://www.w3.org/TR/xml-entity-names/
        "quot": "\u{0022}",
        "amp": "\u{0026}",
        "apos": "\u{0027}",
        "lt": "\u{003C}",
        "gt": "\u{003E}",
        "nbsp": "\u{00A0}",
        "iexcl": "\u{00A1}",
        "cent": "\u{00A2}",
        "pound": "\u{00A3}",
        "curren": "\u{00A4}",
        "yen": "\u{00A5}",
        "brvbar": "\u{00A6}",
        "sect": "\u{00A7}",
        "uml": "\u{00A8}",
        "copy": "\u{00A9}",
        "ordf": "\u{00AA}",
        "laquo": "\u{00AB}",
        "not": "\u{00AC}",
        "shy": "\u{00AD}",
        "reg": "\u{00AE}",
        "macr": "\u{00AF}",
        "deg": "\u{00B0}",
        "plusmn": "\u{00B1}",
        "sup2": "\u{00B2}",
        "sup3": "\u{00B3}",
        "acute": "\u{00B4}",
        "micro": "\u{00B5}",
        "para": "\u{00B6}",
        "middot": "\u{00B7}",
        "cedil": "\u{00B8}",
        "sup1": "\u{00B9}",
        "ordm": "\u{00BA}",
        "raquo": "\u{00BB}",
        "frac14": "\u{00BC}",
        "frac12": "\u{00BD}",
        "frac34": "\u{00BE}",
        "iquest": "\u{00BF}",
        "Agrave": "\u{00C0}",
        "Aacute": "\u{00C1}",
        "Acirc": "\u{00C2}",
        "Atilde": "\u{00C3}",
        "Auml": "\u{00C4}",
        "Aring": "\u{00C5}",
        "AElig": "\u{00C6}",
        "Ccedil": "\u{00C7}",
        "Egrave": "\u{00C8}",
        "Eacute": "\u{00C9}",
        "Ecirc": "\u{00CA}",
        "Euml": "\u{00CB}",
        "Igrave": "\u{00CC}",
        "Iacute": "\u{00CD}",
        "Icirc": "\u{00CE}",
        "Iuml": "\u{00CF}",
        "ETH": "\u{00D0}",
        "Ntilde": "\u{00D1}",
        "Ograve": "\u{00D2}",
        "Oacute": "\u{00D3}",
        "Ocirc": "\u{00D4}",
        "Otilde": "\u{00D5}",
        "Ouml": "\u{00D6}",
        "times": "\u{00D7}",
        "Oslash": "\u{00D8}",
        "Ugrave": "\u{00D9}",
        "Uacute": "\u{00DA}",
        "Ucirc": "\u{00DB}",
        "Uuml": "\u{00DC}",
        "Yacute": "\u{00DD}",
        "THORN": "\u{00DE}",
        "szlig": "\u{00DF}",
        "agrave": "\u{00E0}",
        "aacute": "\u{00E1}",
        "acirc": "\u{00E2}",
        "atilde": "\u{00E3}",
        "auml": "\u{00E4}",
        "aring": "\u{00E5}",
        "aelig": "\u{00E6}",
        "ccedil": "\u{00E7}",
        "egrave": "\u{00E8}",
        "eacute": "\u{00E9}",
        "ecirc": "\u{00EA}",
        "euml": "\u{00EB}",
        "igrave": "\u{00EC}",
        "iacute": "\u{00ED}",
        "icirc": "\u{00EE}",
        "iuml": "\u{00EF}",
        "eth": "\u{00F0}",
        "ntilde": "\u{00F1}",
        "ograve": "\u{00F2}",
        "oacute": "\u{00F3}",
        "ocirc": "\u{00F4}",
        "otilde": "\u{00F5}",
        "ouml": "\u{00F6}",
        "divide": "\u{00F7}",
        "oslash": "\u{00F8}",
        "ugrave": "\u{00F9}",
        "uacute": "\u{00FA}",
        "ucirc": "\u{00FB}",
        "uuml": "\u{00FC}",
        "yacute": "\u{00FD}",
        "thorn": "\u{00FE}",
        "yuml": "\u{00FF}",
        "OElig": "\u{0152}",
        "oelig": "\u{0153}",
        "Scaron": "\u{0160}",
        "scaron": "\u{0161}",
        "Yuml": "\u{0178}",
        "fnof": "\u{0192}",
        "circ": "\u{02C6}",
        "tilde": "\u{02DC}",
        "Alpha": "\u{0391}",
        "Beta": "\u{0392}",
        "Gamma": "\u{0393}",
        "Delta": "\u{0394}",
        "Epsilon": "\u{0395}",
        "Zeta": "\u{0396}",
        "Eta": "\u{0397}",
        "Theta": "\u{0398}",
        "Iota": "\u{0399}",
        "Kappa": "\u{039A}",
        "Lambda": "\u{039B}",
        "Mu": "\u{039C}",
        "Nu": "\u{039D}",
        "Xi": "\u{039E}",
        "Omicron": "\u{039F}",
        "Pi": "\u{03A0}",
        "Rho": "\u{03A1}",
        "Sigma": "\u{03A3}",
        "Tau": "\u{03A4}",
        "Upsilon": "\u{03A5}",
        "Phi": "\u{03A6}",
        "Chi": "\u{03A7}",
        "Psi": "\u{03A8}",
        "Omega": "\u{03A9}",
        "alpha": "\u{03B1}",
        "beta": "\u{03B2}",
        "gamma": "\u{03B3}",
        "delta": "\u{03B4}",
        "epsilon": "\u{03B5}",
        "zeta": "\u{03B6}",
        "eta": "\u{03B7}",
        "theta": "\u{03B8}",
        "iota": "\u{03B9}",
        "kappa": "\u{03BA}",
        "lambda": "\u{03BB}",
        "mu": "\u{03BC}",
        "nu": "\u{03BD}",
        "xi": "\u{03BE}",
        "omicron": "\u{03BF}",
        "pi": "\u{03C0}",
        "rho": "\u{03C1}",
        "sigmaf": "\u{03C2}",
        "sigma": "\u{03C3}",
        "tau": "\u{03C4}",
        "upsilon": "\u{03C5}",
        "phi": "\u{03C6}",
        "chi": "\u{03C7}",
        "psi": "\u{03C8}",
        "omega": "\u{03C9}",
        "thetasym": "\u{03D1}",
        "upsih": "\u{03D2}",
        "piv": "\u{03D6}",
        "ensp": "\u{2002}",
        "emsp": "\u{2003}",
        "thinsp": "\u{2009}",
        "zwnj": "\u{200C}",
        "zwj": "\u{200D}",
        "lrm": "\u{200E}",
        "rlm": "\u{200F}",
        "ndash": "\u{2013}",
        "mdash": "\u{2014}",
        "lsquo": "\u{2018}",
        "rsquo": "\u{2019}",
        "sbquo": "\u{201A}",
        "ldquo": "\u{201C}",
        "rdquo": "\u{201D}",
        "bdquo": "\u{201E}",
        "dagger": "\u{2020}",
        "Dagger": "\u{2021}",
        "bull": "\u{2022}",
        "hellip": "\u{2026}",
        "permil": "\u{2030}",
        "prime": "\u{2032}",
        "Prime": "\u{2033}",
        "lsaquo": "\u{2039}",
        "rsaquo": "\u{203A}",
        "oline": "\u{203E}",
        "frasl": "\u{2044}",
        "euro": "\u{20AC}",
        "image": "\u{2111}",
        "weierp": "\u{2118}",
        "real": "\u{211C}",
        "trade": "\u{2122}",
        "alefsym": "\u{2135}",
        "larr": "\u{2190}",
        "uarr": "\u{2191}",
        "rarr": "\u{2192}",
        "darr": "\u{2193}",
        "harr": "\u{2194}",
        "crarr": "\u{21B5}",
        "lArr": "\u{21D0}",
        "uArr": "\u{21D1}",
        "rArr": "\u{21D2}",
        "dArr": "\u{21D3}",
        "hArr": "\u{21D4}",
        "forall": "\u{2200}",
        "part": "\u{2202}",
        "exist": "\u{2203}",
        "empty": "\u{2205}",
        "nabla": "\u{2207}",
        "isin": "\u{2208}",
        "notin": "\u{2209}",
        "ni": "\u{220B}",
        "prod": "\u{220F}",
        "sum": "\u{2211}",
        "minus": "\u{2212}",
        "lowast": "\u{2217}",
        "radic": "\u{221A}",
        "prop": "\u{221D}",
        "infin": "\u{221E}",
        "ang": "\u{2220}",
        "and": "\u{2227}",
        "or": "\u{2228}",
        "cap": "\u{2229}",
        "cup": "\u{222A}",
        "int": "\u{222B}",
        "there4": "\u{2234}",
        "sim": "\u{223C}",
        "cong": "\u{2245}",
        "asymp": "\u{2248}",
        "ne": "\u{2260}",
        "equiv": "\u{2261}",
        "le": "\u{2264}",
        "ge": "\u{2265}",
        "sub": "\u{2282}",
        "sup": "\u{2283}",
        "nsub": "\u{2284}",
        "sube": "\u{2286}",
        "supe": "\u{2287}",
        "oplus": "\u{2295}",
        "otimes": "\u{2297}",
        "perp": "\u{22A5}",
        "sdot": "\u{22C5}",
        "lceil": "\u{2308}",
        "rceil": "\u{2309}",
        "lfloor": "\u{230A}",
        "rfloor": "\u{230B}",
        "lang": "\u{2329}",
        "rang": "\u{232A}",
        "loz": "\u{25CA}",
        "spades": "\u{2660}",
        "clubs": "\u{2663}",
        "hearts": "\u{2665}",
        "diams": "\u{2666}",

        // Special cases from Windows-1252. https://en.wikipedia.org/wiki/Windows-1252
        "#128": "\u{20AC}",
        "#130": "\u{201A}",
        "#131": "\u{0192}",
        "#132": "\u{201E}",
        "#133": "\u{2026}",
        "#134": "\u{2020}",
        "#135": "\u{2021}",
        "#136": "\u{02C6}",
        "#138": "\u{0160}",
        "#139": "\u{2039}",
        "#140": "\u{0152}",
        "#142": "\u{017D}",
        "#145": "\u{2018}",
        "#146": "\u{2019}",
        "#147": "\u{201C}",
        "#148": "\u{201D}",
        "#149": "\u{2022}",
        "#150": "\u{2013}",
        "#151": "\u{2014}",
        "#152": "\u{02DC}",
        "#153": "\u{2122}",
        "#154": "\u{0161}",
        "#155": "\u{203A}",
        "#156": "\u{0153}",
        "#158": "\u{017E}",
        "#159": "\u{0178}"]
}
