//
//  OKSwiftFunction.swift
//  OneKit
//
//  Created by bob on 2021/1/14.
//

import MachO
import Foundation
import OneKit

public class OKSwiftFunction {
    lazy var exportedSymbols = [String : UnsafeMutableRawPointer?]()
    lazy var organizedSymbols = [String : [UnsafeMutableRawPointer?]]()
    var namespace : String
    
    //static let functionQueue = DispatchQueue(label: "onekit.function.queue")
    
    public convenience init(namespace: String) {
        self.init(privately: namespace)
        setup()
    }

    private init(privately: String) {
        self.namespace = privately
    }
    
    static let `default` = OKSwiftFunction(namespace: "OneKit")
    
    lazy var fullNamespace = "_" + namespace + "."
    
    static func dumpAllExportedSymbol() {
        _dyld_register_func_for_add_image { (image, slide) in
            var info = Dl_info()
            if (dladdr(image, &info) == 0) {
                return
            }
            if (!String(cString: info.dli_fname).hasPrefix(Bundle.main.bundlePath)) {
                return
            }
            let exportedSymbols = OKSwiftFunction.default.getExportedSymbols(image: image, slide: slide)
            exportedSymbols.forEach { (key, symbol) in
                //OKSwiftFunction.functionQueue.sync {
                    OKSwiftFunction.default.addSymbol(key: key, symbol: symbol)
                //}
            }
        }
    }
    
    func setup() {
        for i in 0..<_dyld_image_count() {
            let exportedSymbols = getExportedSymbols(image: _dyld_get_image_header(i), slide: _dyld_get_image_vmaddr_slide(i))
            exportedSymbols.forEach { (key, symbol) in
                //OKSwiftFunction.functionQueue.sync {
                    addSymbol(key: key, symbol: symbol)
                //}
            }
        }
    }
    
    func addSymbol(key: String, symbol: UnsafeMutableRawPointer?) {
        self.exportedSymbols[key] = symbol
    }
    
    
    /// http://www.itkeyword.com/doc/143214251714949x965/uleb128p1-sleb128-uleb128
    static func readUleb128(p: inout UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>) -> UInt64 {
        var result: UInt64 = 0
        var bit = 0
        var read_next = true
        
        repeat {
            if p == end {
                assert(false, "malformed uleb128")
            }
            let slice = UInt64(p.pointee & 0x7f)
            if bit > 63 {
                assert(false, "uleb128 too big for uint64")
            } else {
                result |= (slice << bit)
                bit += 7
            }
            read_next = (p.pointee & 0x80) != 0  // = 128
            p += 1
        } while (read_next)
        
        return result
    }
    
    static let setup: () = {
        dumpAllExportedSymbol()
    }()

    
    public class func start(key: String) {
        OKSwiftFunction.default.start(key: key)
    }
    
    public func start(key: String) {
        typealias classFunc = @convention(thin) () -> Void
        var keySymbols : [UnsafeMutableRawPointer?] = []
        //OKSwiftFunction.functionQueue.sync {
            if let organizedKeySymbols = organizedSymbols[key] {
                keySymbols = organizedKeySymbols
            } else {
                exportedSymbols.forEach { (fullKey, symbol) in
                    if fullKey.hasPrefix(fullNamespace + key + ".") || fullKey == fullNamespace + key {
                        keySymbols.append(symbol)
                        exportedSymbols.removeValue(forKey: fullKey)
                    }
                }
                organizedSymbols[key] = keySymbols
            }
        //}
        keySymbols.forEach { (symbol) in
            let f = unsafeBitCast(symbol, to: classFunc.self)
            f()
        }
    }

    private static let linkeditName = SEG_LINKEDIT.utf8CString
    func getExportedSymbols(image:UnsafePointer<mach_header>!, slide: Int) -> [String : UnsafeMutableRawPointer?] {
        var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
        var dynamicLoadInfoCmd: UnsafeMutablePointer<dyld_info_command>!
        
        var curCmd = UnsafeMutableRawPointer(mutating: image).advanced(by: MemoryLayout<mach_header_64>.size).assumingMemoryBound(to: segment_command_64.self)
        
        for _ in 0..<image.pointee.ncmds {
            if curCmd.pointee.cmd == LC_SEGMENT_64 {
                
                if  curCmd.pointee.segname.0 == OKSwiftFunction.linkeditName[0] &&
                        curCmd.pointee.segname.1 == OKSwiftFunction.linkeditName[1] &&
                        curCmd.pointee.segname.2 == OKSwiftFunction.linkeditName[2] &&
                        curCmd.pointee.segname.3 == OKSwiftFunction.linkeditName[3] &&
                        curCmd.pointee.segname.4 == OKSwiftFunction.linkeditName[4] &&
                        curCmd.pointee.segname.5 == OKSwiftFunction.linkeditName[5] &&
                        curCmd.pointee.segname.6 == OKSwiftFunction.linkeditName[6] &&
                        curCmd.pointee.segname.7 == OKSwiftFunction.linkeditName[7] &&
                        curCmd.pointee.segname.8 == OKSwiftFunction.linkeditName[8] &&
                        curCmd.pointee.segname.9 == OKSwiftFunction.linkeditName[9] {
                    linkeditCmd = curCmd
                }
            } else if curCmd.pointee.cmd == LC_DYLD_INFO_ONLY || curCmd.pointee.cmd == LC_DYLD_INFO {
                dynamicLoadInfoCmd = curCmd.withMemoryRebound(to: dyld_info_command.self, capacity: 1, { $0 })
            }
            
            let curCmdSize = Int(curCmd.pointee.cmdsize)
            let _curCmd = curCmd.withMemoryRebound(to: Int8.self, capacity: 1, { $0 }).advanced(by: curCmdSize)
            curCmd = _curCmd.withMemoryRebound(to: segment_command_64.self, capacity: 1, { $0 })
        }
        
        if linkeditCmd == nil || dynamicLoadInfoCmd == nil {
            return [String : UnsafeMutableRawPointer?]()
        }
        
        let linkeditBase = slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff)
        guard let exportedInfo = UnsafeMutableRawPointer(bitPattern: linkeditBase + Int(dynamicLoadInfoCmd.pointee.export_off))?.assumingMemoryBound(to: UInt8.self) else {
            return [String : UnsafeMutableRawPointer?]()
        }
        let exportedInfoSize = Int(dynamicLoadInfoCmd.pointee.export_size)
        
        var symbols = [String : UnsafeMutableRawPointer?]()
        trieWalk(image: image, start: exportedInfo, loc: exportedInfo, end: exportedInfo + exportedInfoSize, currentSymbol: "", symbols: &symbols)
        
        return symbols
    }
    

    
    private func trieWalk(image:UnsafePointer<mach_header>!,
                                 start:UnsafeMutablePointer<UInt8>,
                                 loc:UnsafeMutablePointer<UInt8>,
                                 end:UnsafeMutablePointer<UInt8>,
                                 currentSymbol: String,
                                 symbols: inout [String : UnsafeMutableRawPointer?]) {
        var p = loc
        if p <= end {
            var terminalSize = UInt64(p.pointee)
            if terminalSize > 127 {
                p -= 1
                terminalSize = OKSwiftFunction.readUleb128(p: &p, end: end)
            }
            if terminalSize != 0 {
                guard currentSymbol.hasPrefix(fullNamespace) else {
                    return
                }

                let returnSwiftSymbolAddress = { () -> UnsafeMutableRawPointer in
                    let machO = image.withMemoryRebound(to: Int8.self, capacity: 1, { $0 })
                    let swiftSymbolAddress = machO.advanced(by: Int(OKSwiftFunction.readUleb128(p: &p, end: end)))
                    return UnsafeMutableRawPointer(mutating: swiftSymbolAddress)
                }
                
                p += 1
                let flags = OKSwiftFunction.readUleb128(p: &p, end: end)
                switch flags & UInt64(EXPORT_SYMBOL_FLAGS_KIND_MASK) {
                case UInt64(EXPORT_SYMBOL_FLAGS_KIND_REGULAR):
                    symbols[currentSymbol] = returnSwiftSymbolAddress()
                case UInt64(EXPORT_SYMBOL_FLAGS_KIND_THREAD_LOCAL):
                    if (flags & UInt64(EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER) != 0) {
                    }
                case UInt64(EXPORT_SYMBOL_FLAGS_KIND_ABSOLUTE):
                    if (flags & UInt64(EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER) != 0) {
                    }
                    symbols[currentSymbol] = UnsafeMutableRawPointer(bitPattern: UInt(OKSwiftFunction.readUleb128(p: &p, end: end)))
                default:
                    break
                }
            }
            
            let child = loc.advanced(by: Int(terminalSize + 1))
            let childCount = child.pointee
            p = child + 1
            for _ in 0 ..< childCount {
                let nodeLabel = String(cString: p.withMemoryRebound(to: CChar.self, capacity: 1, { $0 }), encoding: .utf8)
                // advance to the end of node's label
                while p.pointee != 0 {
                    p += 1
                }
                
                // so advance to the child's node
                p += 1
                let nodeOffset = Int(OKSwiftFunction.readUleb128(p: &p, end: end))
                if nodeOffset != 0, let nodeLabel = nodeLabel {
                    let symbol = currentSymbol + nodeLabel
//                    print(currentSymbol + " + " + nodeLabel)
                    // find common parent node first then get all _Gaia: node.
                    if symbol.lengthOfBytes(using: .utf8) > 0 && (symbol.hasPrefix(fullNamespace) || fullNamespace.hasPrefix(symbol)) {
                        trieWalk(image: image, start: start, loc: start.advanced(by: nodeOffset), end: end, currentSymbol: symbol, symbols: &symbols)
                    }
                }
            }
        }
    }
}

extension OKSectionFunction {
    @objc public func excuteSwiftFunctions(forKey: String) {
        OKSwiftFunction.start(key: forKey)
    }
}


