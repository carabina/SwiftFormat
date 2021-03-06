//
//  SwiftFormat
//  Tokenizer.swift
//
//  Version 0.3
//
//  Created by Nick Lockwood on 11/08/2016.
//  Copyright 2016 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/SwiftFormat
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation

// https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html

public enum TokenType {
    case Number
    case Linebreak
    case StartOfScope
    case EndOfScope
    case Operator
    case StringBody
    case Identifier
    case Whitespace
    case CommentBody
}

public struct Token: Equatable {
    public let type: TokenType
    public let string: String
    
    public init(_ type: TokenType, _ string: String) {
        self.type = type
        self.string = string
    }
    
    public var isWhitespaceOrComment: Bool {
        switch type {
        case .Whitespace, .CommentBody:
            return true
        case .StartOfScope:
            return string == "//" || string == "/*"
        case .EndOfScope:
            return string == "//"
        default:
            return false
        }
    }
    
    public var isWhitespaceOrCommentOrLinebreak: Bool {
        return type == .Linebreak || isWhitespaceOrComment
    }
    
    public func closesScopeForToken(token: Token) -> Bool {
        guard type != .StringBody && type != .CommentBody else {
            return false
        }
        switch token.string {
        case "(":
            return string == ")"
        case "[":
            return string == "]"
        case "{":
            return string == "}"
        case "<":
            return string.hasPrefix(">")
        case "\"":
            return string == "\""
        case "/*":
            return string == "*/"
        case "//":
            return type == .Linebreak
        case "#if":
            return string == "#endif"
        default:
            return false
        }
    }
}

public func ==(lhs: Token, rhs: Token) -> Bool {
    return lhs.type == rhs.type && lhs.string == rhs.string
}

private extension Character {
    
    var unicodeValue: UInt32 {
        return String(self).unicodeScalars.first?.value ?? 0
    }
    
    var isAlpha: Bool { return isalpha(Int32(unicodeValue)) > 0 }
    var isDigit: Bool { return isdigit(Int32(unicodeValue)) > 0 }
}

private extension String.CharacterView {
    
    mutating func scanCharacter(matching: (Character) -> Bool) -> String? {
        if let c = first where matching(c) {
            self = suffixFrom(startIndex.advancedBy(1))
            return String(c)
        }
        return nil
    }
    
    mutating func scanString(matching string: String) -> String? {
        if startsWith(string.characters) {
            self = suffixFrom(startIndex.advancedBy(string.characters.count))
            return string
        }
        return nil
    }
    
    mutating func scanCharacters(matching: (Character) -> Bool) -> String? {
        var index = endIndex
        for (i, c) in enumerate() {
            if !matching(c) {
                index = startIndex.advancedBy(i)
                break
            }
        }
        if index > startIndex {
            let string = String(prefixUpTo(index))
            self = suffixFrom(index)
            return string
        }
        return nil
    }
    
    mutating func scanInteger() -> String? {
        return scanCharacters({ $0.isDigit })
    }
}

private extension String.CharacterView {
    
    mutating func parseToken(type: TokenType, _ character: Character) -> Token? {
        if let _ = scanCharacter({ $0 == character }) {
            return Token(type, String(character))
        }
        return nil
    }
    
    mutating func parseToken(type: TokenType, _ string: String) -> Token? {
        if let string = scanString(matching: string) {
            return Token(type, string)
        }
        return nil
    }
    
    mutating func parseToken(type: TokenType, oneOf characters: String.CharacterView) -> Token? {
        if let string = scanCharacter({ characters.contains($0) }) {
            return Token(type, String(string))
        }
        return nil
    }
    
    mutating func parseToken(type: TokenType, _ characters: String.CharacterView) -> Token? {
        if let string = scanCharacters({ characters.contains($0) }) {
            return Token(type, string)
        }
        return nil
    }
    
    mutating func parseToken(type: TokenType, upTo characters: String.CharacterView) -> Token? {
        if let string = scanCharacters({ !characters.contains($0) }) {
            return Token(type, string)
        }
        return nil
    }
    
    mutating func parseToken(type: TokenType, upTo character: Character) -> Token? {
        if let string = scanCharacters({ $0 != character }) {
            return Token(type, string)
        }
        return nil
    }
}

private extension String.CharacterView {
    
    mutating func parseWhitespace() -> Token? {
        return parseToken(.Whitespace, " \t".characters) // TODO: vertical tab
    }
    
    mutating func parseOperator() -> Token? {
        func isHead(c: Character) -> Bool {
            if "./=­-+!*%<>&|^~?".characters.contains(c) {
                return true
            }
            switch c.unicodeValue {
            case 0x00A1 ... 0x00A7,
                    0x00A9, 0x00AB, 0x00AC, 0x00AE,
                    0x00B0 ... 0x00B1,
                    0x00B6, 0x00BB, 0x00BF, 0x00D7, 0x00F7,
                    0x2016 ... 0x2017,
                    0x2020 ... 0x2027,
                    0x2030 ... 0x203E,
                    0x2041 ... 0x2053,
                    0x2055 ... 0x205E,
                    0x2190 ... 0x23FF,
                    0x2500 ... 0x2775,
                    0x2794 ... 0x2BFF,
                    0x2E00 ... 0x2E7F,
                    0x3001 ... 0x3003,
                    0x3008 ... 0x3030:
                return true
            default:
                return false
            }
        }
        
        func isTail(c: Character) -> Bool {
            if isHead(c) {
                return true
            }
            switch c.unicodeValue {
            case 0x0300 ... 0x036F,
                    0x1DC0 ... 0x1DFF,
                    0x20D0 ... 0x20FF,
                    0xFE00 ... 0xFE0F,
                    0xFE20 ... 0xFE2F,
                    0xE0100 ... 0xE01EF:
                return true
            default:
                return false
            }
        }
        
        func scanOperator() -> String? {
            if let head = scanCharacter(isHead) {
                if let tail = scanCharacters(isTail) {
                    return head + tail
                }
                return head
            }
            return nil
        }
        
        if let op = scanOperator() {
            return Token(.Operator, op)
        }
        return parseToken(.Operator, ":;,".characters)
    }
    
    mutating func parseStartOfScope() -> Token? {
        return parseToken(.StartOfScope, oneOf: "([{\"".characters)
    }
    
    mutating func parseEndOfScope() -> Token? {
        return parseToken(.EndOfScope, oneOf: "}])".characters)
    }
    
    mutating func parseIdentifier() -> Token? {
        func isHead(c: Character) -> Bool {
            if c.isAlpha || c == "_" || c == "$" {
                return true
            }
            switch c.unicodeValue {
            case 0x00A8, 0x00AA, 0x00AD, 0x00AF,
                    0x00B2 ... 0x00B5,
                    0x00B7 ... 0x00BA,
                    0x00BC ... 0x00BE,
                    0x00C0 ... 0x00D6,
                    0x00D8 ... 0x00F6,
                    0x00F8 ... 0x00FF,
                    0x0100 ... 0x02FF,
                    0x0370 ... 0x167F,
                    0x1681 ... 0x180D,
                    0x180F ... 0x1DBF,
                    0x1E00 ... 0x1FFF,
                    0x200B ... 0x200D,
                    0x202A ... 0x202E,
                    0x203F ... 0x2040,
                    0x2054,
                    0x2060 ... 0x206F,
                    0x2070 ... 0x20CF,
                    0x2100 ... 0x218F,
                    0x2460 ... 0x24FF,
                    0x2776 ... 0x2793,
                    0x2C00 ... 0x2DFF,
                    0x2E80 ... 0x2FFF,
                    0x3004 ... 0x3007,
                    0x3021 ... 0x302F,
                    0x3031 ... 0x303F,
                    0x3040 ... 0xD7FF,
                    0xF900 ... 0xFD3D,
                    0xFD40 ... 0xFDCF,
                    0xFDF0 ... 0xFE1F,
                    0xFE30 ... 0xFE44,
                    0xFE47 ... 0xFFFD,
                    0x10000 ... 0x1FFFD,
                    0x20000 ... 0x2FFFD,
                    0x30000 ... 0x3FFFD,
                    0x40000 ... 0x4FFFD,
                    0x50000 ... 0x5FFFD,
                    0x60000 ... 0x6FFFD,
                    0x70000 ... 0x7FFFD,
                    0x80000 ... 0x8FFFD,
                    0x90000 ... 0x9FFFD,
                    0xA0000 ... 0xAFFFD,
                    0xB0000 ... 0xBFFFD,
                    0xC0000 ... 0xCFFFD,
                    0xD0000 ... 0xDFFFD,
                    0xE0000 ... 0xEFFFD:
                return true
            default:
                return false
            }
        }
        
        func isTail(c: Character) -> Bool {
            if isHead(c) || c.isDigit {
                return true
            }
            switch c.unicodeValue {
            case 0x0300 ... 0x036F,
                    0x1DC0 ... 0x1DFF,
                    0x20D0 ... 0x20FF,
                    0xFE20 ... 0xFE2F:
                return true
            default:
                return false
            }
        }
        
        func scanIdentifier() -> String? {
            if let head = scanCharacter({ isHead($0) || $0 == "@" || $0 == "#" }) {
                if let tail = scanCharacters({ isTail($0) }) {
                    return head + tail
                }
                return head
            }
            return nil
        }
        
        let start = self
        if scanCharacter({ $0 == "`" }) != nil {
            if let identifier = scanIdentifier() {
                if scanCharacter({ $0 == "`" }) != nil {
                    return Token(.Identifier, "`" + identifier + "`")
                }
            }
            self = start
        } else if let identifier = scanIdentifier() {
            if identifier == "#if" {
                return Token(.StartOfScope, identifier)
            }
            if identifier == "#endif" {
                return Token(.EndOfScope, identifier)
            }
            return Token(.Identifier, identifier)
        }
        return nil
    }
    
    mutating func parseNumber() -> Token? {
        var number = ""
        if let integer = scanInteger() {
            number = integer
            let endOfInt = self
            if scanCharacter({ $0 == "." }) != nil {
                if let fraction = scanInteger() {
                    number += "." + fraction
                } else {
                    self = endOfInt
                }
            }
            let endOfFloat = self
            if let e = scanCharacter({ $0 == "e" || $0 == "E" }) {
                let sign = scanCharacter({ $0 == "-" || $0 == "+" }) ?? ""
                if let exponent = scanInteger() {
                    number += e + sign + exponent
                } else {
                    self = endOfFloat
                }
            }
            return Token(.Number, number)
        }
        return nil
    }
    
    mutating func parseLineBreak() -> Token? {
        if scanCharacter({ $0 == "\r" }) != nil {
            if scanCharacter({ $0 == "\n" }) != nil {
                return Token(.Linebreak, "\r\n")
            }
            return Token(.Linebreak, "\r")
        }
        return parseToken(.Linebreak, "\n")
    }
    
    mutating func parseComment() -> Token? {
        let start = self
        if scanCharacter({ $0 == "/" }) != nil {
            if let c = scanCharacter({ $0 == "*" || $0 == "/" }) {
                return Token(.StartOfScope, "/" + c)
            }
            // TODO: Must be an operator starting with / so we could
            // shortcut the parsing process here if we wanted to
            self = start
        }
        return nil
    }
    
    mutating func parseToken() -> Token? {
        // Have to split into groups for Swift to be able to process this
        if let token = parseWhitespace() ??
            parseComment() ??
            parseIdentifier() ??
            parseNumber() {
            return token
        }
        if let token = parseOperator() ??
            parseStartOfScope() ??
            parseEndOfScope() ??
            parseLineBreak() {
            return token
        }
        if count > 0 {
            assertionFailure("Unrecognized token: " + String(self))
        }
        return nil
    }
}

func tokenize(source: String) -> [Token] {
    var scopeIndexStack: [Int] = []
    var tokens: [Token] = []
    var characters = source.characters
    var lastNonWhitespaceIndex: Int?
    var closedGenericScopeIndexes: [Int] = []
    
    func processStringBody() {
        var string = ""
        var escaped = false
        while let c = characters.scanCharacter({ _ in true }) {
            switch c {
            case "\\":
                escaped = !escaped
            case "\"":
                if !escaped {
                    if string != "" {
                        tokens.append(Token(.StringBody, string))
                    }
                    tokens.append(Token(.EndOfScope, "\""))
                    scopeIndexStack.popLast()
                    return
                }
                escaped = false
            case "(":
                if escaped {
                    if string != "" {
                        tokens.append(Token(.StringBody, string))
                    }
                    scopeIndexStack.append(tokens.count)
                    tokens.append(Token(.StartOfScope, "("))
                    return
                }
                escaped = false
            default:
                escaped = false
            }
            string += c
        }
    }
    
    func processCommentBody() {
        var comment = ""
        while let c = characters.scanCharacter({ _ in true }) {
            if c == "/" {
                if characters.scanCharacter({ $0 == "*" }) != nil {
                    if comment != "" {
                        tokens.append(Token(.CommentBody, comment))
                    }
                    scopeIndexStack.append(tokens.count)
                    tokens.append(Token(.StartOfScope, "/*"))
                    comment = ""
                    continue
                }
            } else if c == "*" {
                if characters.scanCharacter({ $0 == "/" }) != nil {
                    if comment != "" {
                        tokens.append(Token(.CommentBody, comment))
                    }
                    tokens.append(Token(.EndOfScope, "*/"))
                    scopeIndexStack.popLast()
                    if scopeIndexStack.last == nil || tokens[scopeIndexStack.last!].string != "/*" {
                        return
                    }
                    comment = ""
                    continue
                }
            } else if c == "\n" {
                if comment != "" {
                    tokens.append(Token(.CommentBody, comment))
                }
                tokens.append(Token(.Linebreak, "\n"))
                if let token = characters.parseWhitespace() {
                    tokens.append(token)
                }
                comment = ""
                continue
            }
            comment += c
        }
    }
    
    func processToken() {
        let token = tokens.last!
        if token.type != .Whitespace {
            // Fix up misidentified generic that is actually a pair of operators
            if let lastNonWhitespaceIndex = lastNonWhitespaceIndex {
                let lastToken = tokens[lastNonWhitespaceIndex]
                if lastToken.string == ">" && lastToken.type == .EndOfScope {
                    var wasOperator = false
                    switch token.type {
                    case .Identifier, .Number:
                        switch token.string {
                        case "in", "is", "as", "where", "else":
                            wasOperator = false
                        default:
                            wasOperator = true
                        }
                    case .StartOfScope:
                        wasOperator = (token.string == "\"")
                    case .Operator:
                        wasOperator = !["->", ">", ",", ":", ";", "?", "!", "."].contains(token.string)
                    default:
                        wasOperator = false
                    }
                    if wasOperator {
                        tokens[closedGenericScopeIndexes.last!] = Token(.Operator, "<")
                        closedGenericScopeIndexes.popLast()
                        if token.type == .Operator && lastNonWhitespaceIndex == tokens.count - 2 {
                            // Need to stitch the operator back together
                            tokens[lastNonWhitespaceIndex] = Token(.Operator, ">" + token.string)
                            tokens.removeLast()
                        } else {
                            tokens[lastNonWhitespaceIndex] = Token(.Operator, ">")
                        }
                        // TODO: this is horrible - need to take a better approach
                        var previousIndex = lastNonWhitespaceIndex - 1
                        var previousToken = tokens[previousIndex]
                        while previousToken.string == ">" {
                            if previousToken.type == .EndOfScope {
                                tokens[closedGenericScopeIndexes.last!] = Token(.Operator, "<")
                                closedGenericScopeIndexes.popLast()
                            }
                            tokens[previousIndex] = Token(.Operator, ">" + tokens[previousIndex + 1].string)
                            tokens.removeAtIndex(previousIndex + 1)
                            previousIndex -= 1
                            previousToken = tokens[previousIndex]
                        }
                        processToken()
                        return
                    }
                }
            }
            lastNonWhitespaceIndex = tokens.count - 1
        }
        if let scopeIndex = scopeIndexStack.last {
            let scope = tokens[scopeIndex]
            if token.closesScopeForToken(scope) {
                scopeIndexStack.popLast()
                if token.string.hasPrefix(">") {
                    // Check if it was a confirmed generic
                    assert(scope.string == "<")
                    if scope.type == .StartOfScope {
                        closedGenericScopeIndexes.append(scopeIndex)
                        tokens[tokens.count - 1] = Token(.EndOfScope, ">")
                        if token.string != ">" {
                            // Need to split the token
                            let suffix = String(token.string.characters.dropFirst())
                            tokens.append(Token(.Operator, suffix))
                            processToken()
                            return
                        }
                    }
                } else if scopeIndexStack.last != nil && tokens[scopeIndexStack.last!].string == "\"" {
                    processStringBody()
                }
                return
            } else if scope.string == "<" {
                if scope.type == .Operator {
                    // Scope hasn't been confirmed as a generic yet
                    switch token.type {
                    case .StartOfScope:
                        if ["<", "[", "("].contains(token.string) {
                            // Assume token is an identifier until proven otherwise
                            tokens[scopeIndex] = Token(.StartOfScope, "<")
                            processToken()
                            return
                        }
                        // Opening < must have been an operator
                        scopeIndexStack.removeAtIndex(scopeIndexStack.count - 2)
                    case .Identifier:
                        // If the first token is an identifier, we'll assume
                        // that it's a generic until proven otherwise
                        tokens[scopeIndex] = Token(.StartOfScope, "<")
                        processToken()
                        return
                    case .Whitespace, .Linebreak:
                        // Might be generic or operator - can't tell yet
                        return
                    default:
                        // Opening < must have been an operator
                        scopeIndexStack.popLast()
                    }
                } else {
                    // We think it's a generic at this point, but could be wrong
                    switch token.type {
                    case .Operator:
                        if !["?>", "!>"].contains(token.string) {
                            fallthrough
                        }
                        // Need to split token
                        tokens[tokens.count - 1] = Token(.Operator, "?")
                        let suffix = String(token.string.characters.dropFirst())
                        tokens.append(Token(.Operator, suffix))
                        processToken()
                        return
                    case .StartOfScope:
                        if !["<", "[", "(", ".", ",", ":", "==", "?", "!"].contains(token.string) {
                            // Not a generic scope
                            tokens[scopeIndex] = Token(.Operator, "<")
                            scopeIndexStack.popLast()
                            processToken()
                            return
                        }
                    case .EndOfScope:
                        // If we encountered a scope token that wasn't a < or >
                        // then the opening < must have been an operator after all
                        tokens[scopeIndex] = Token(.Operator, "<")
                        scopeIndexStack.popLast()
                        processToken()
                        return
                    default:
                        break
                    }
                }
            }
        }
        if token.type == .StartOfScope {
            scopeIndexStack.append(tokens.count - 1)
            if token.string == "\"" {
                processStringBody()
            } else if token.string == "/*" {
                if let whitespace = characters.parseWhitespace() {
                    tokens.append(whitespace)
                }
                processCommentBody()
            } else if token.string == "//" {
                if let whitespace = characters.parseWhitespace() {
                    tokens.append(whitespace)
                }
                if let comment = characters.scanCharacters({ $0 != "\n" && $0 != "\r" }) {
                    tokens.append(Token(.CommentBody, comment))
                }
                scopeIndexStack.popLast()
            }
        } else if token.type == .Operator && token.string == "<" {
            // Potentially the start of a generic, so we'll add to scope stack
            scopeIndexStack.append(tokens.count - 1)
        }
    }
    
    while let token = characters.parseToken() {
        tokens.append(token)
        processToken()
    }
    
    if let scopeIndex = scopeIndexStack.last {
        let scope = tokens[scopeIndex]
        if scope.type == .StartOfScope && scope.string == "<" {
            // If we encountered an end-of-file while a generic scope was
            // still open, the opening < must have been an operator after all
            tokens[scopeIndex] = Token(.Operator, "<")
            scopeIndexStack.popLast()
        }
    }
    
    return tokens
}
