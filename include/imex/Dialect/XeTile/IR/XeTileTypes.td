//===---------------- XeTileTypes.td - XeTile dialect  -------*- tablegen -*-===//
//
// Copyright 2022 Intel Corporation
// Part of the IMEX Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file defines the custom types used by XeTile dialect.
///
//===----------------------------------------------------------------------===//
#ifndef _XETILE_TYPES_TD_INCLUDED_
#define _XETILE_TYPES_TD_INCLUDED_


include "imex/Dialect/XeTile/IR/XeTileDialect.td"

// common base class for types in XeTile dialect
class XeTile_Type<string name, string typeMnemonic, list<Trait> traits = [],
                 string baseCppClass = "mlir::Type">
    : TypeDef<XeTile_Dialect, name, traits, baseCppClass> {
    let mnemonic = typeMnemonic;
}

def XeTile : XeTile_Type<"Tile", "tile", [ShapedTypeInterface],
                            "mlir::TensorType">
{
  let summary = "A type representing a N-D tile";
  let description = [{
      Tile data type in XeTile dialect is used to represent an N-D memory region. This captures the
      2d shape and type of the memory region it points to. Optional encoding attribute can be
      attached to the tile type to carry extra information such as data layout information.

      Syntax:

      ```
      tile-type ::= `tile` `<` tile-dim-list element-type (`,` encoding )? `>`
      element-type ::= float-type | integer-type
      tile-dim-list := (decimal-literal `x`)*
      encoding ::= attribute-value
      ```

      Examples:

      ```mlir
      // 2D tile with i32 elements
      tile<3x42xi32>

      // 4D tile with f32 elements
      tile<4x5x6x7xf32>

      // 2D tile with i16 elements and encoding
      tile<64x64xi16, #encoding>

      ```
  }];

  let parameters = (ins ArrayRefParameter<"int64_t">:$shape,
                        "mlir::Type":$elementType,
                        OptionalParameter<"mlir::Attribute">:$encoding);

  let builders = [
    TypeBuilderWithInferredContext<(ins
      "llvm::ArrayRef<int64_t>":$shape,
      "mlir::Type":$elementType,
      CArg<"mlir::Attribute", "{}">:$encoding
    ), [{
      return $_get(elementType.getContext(), shape, elementType, encoding);
    }]>
  ];

  let extraClassDeclaration = [{
    using TensorType::clone;
    using mlir::ShapedType::Trait<TileType>::getElementTypeBitWidth;
    using mlir::ShapedType::Trait<TileType>::getRank;
    using mlir::ShapedType::Trait<TileType>::getNumElements;
    using mlir::ShapedType::Trait<TileType>::isDynamicDim;
    using mlir::ShapedType::Trait<TileType>::hasStaticShape;
    using mlir::ShapedType::Trait<TileType>::getNumDynamicDims;
    using mlir::ShapedType::Trait<TileType>::getDimSize;
    using mlir::ShapedType::Trait<TileType>::getDynamicDimIndex;

    TileType clone(mlir::Type elementType) {
      return llvm::cast<TileType>(cloneWith(getShape(), elementType));
    }

    xetile::SubGroupMapAttr getSgMap() {
      auto encoding = llvm::dyn_cast_if_present<xetile::XeTileAttr>(getEncoding());
      if (encoding)
        return encoding.getSgMap();
      return xetile::SubGroupMapAttr();
    }

    xetile::WorkGroupMapAttr getWgMap() {
      auto wgmap = llvm::dyn_cast_if_present<xetile::WorkGroupMapAttr>(getEncoding());
      if (wgmap)
            return wgmap;
      auto encoding = llvm::dyn_cast_if_present<xetile::XeTileAttr>(getEncoding());
      if (encoding)
        return encoding.getWgMap();
      return xetile::WorkGroupMapAttr();
    }

    mlir::DenseI64ArrayAttr getInnerBlocks() {
      auto encoding = llvm::dyn_cast_if_present<xetile::XeTileAttr>(getEncoding());
      if (encoding)
        return encoding.getInnerBlocks();
      return mlir::DenseI64ArrayAttr();
    }

    mlir::DenseI32ArrayAttr getOrder() {
      auto encoding = llvm::dyn_cast_if_present<xetile::XeTileAttr>(getEncoding());
      if (encoding)
        return encoding.getOrder();
      return mlir::DenseI32ArrayAttr::get(getContext(), {1, 0});
    }

    mlir::Attribute getMemoryScope() {
      auto encoding = llvm::dyn_cast_if_present<xetile::XeTileAttr>(getEncoding());
      if (encoding)
        return encoding.getMemoryScope();
      return mlir::Attribute();
    }

    int getMemoryScopeAsInt() {
      auto encoding = llvm::dyn_cast_if_present<xetile::XeTileAttr>(getEncoding());
      if (encoding && encoding.getMemoryScope()) {
        auto memoryScope = encoding.getMemoryScope();
        assert(mlir::isa<mlir::IntegerAttr>(memoryScope) &&
              "Using `getMemorySpaceAsInt` with non-Integer attribute");
        return mlir::cast<mlir::IntegerAttr>(memoryScope).getInt();
      }
      // return default value 0 indicating Global memory
      return 0;
    }

  }];

  let assemblyFormat = "`<` custom<XeTileType>($shape, $elementType, $encoding) `>`";
  let genVerifyDecl = true;
}

// Integer types allowd in XeTile
def XeTile_IntType : AnyTypeOf<[I1, I8, I16, I32, I64, SI1, SI8, SI16, SI32, SI64, UI1, UI8, UI16, UI32, UI64]>;

// Float types allowed in XeTile
def XeTile_FloatType : AnyTypeOf<[F16, F32, F64, BF16, TF32]>;

// Define the scalar type for XeTile
def XeTile_ScalarType : AnyTypeOf<[XeTile_IntType, XeTile_FloatType]>;

// define a 1D or 2D memref of XeTile scalar type
def XeTile_DynamicMemref : Non0RankedMemRefOf<[XeTile_ScalarType]>;

// define the source type for XeTile init_tile
def XeTile_BaseAddrType : AnyTypeOf<[XeTile_DynamicMemref, UI64, UI32, I64, I32]>;

// input and output types needed for pack and unpack ops
def XeTile_2DVector : VectorOfRankAndType<[2], [XeTile_ScalarType]>;
def XeTile_4DVector : VectorOfRankAndType<[4], [XeTile_ScalarType]>;

// define the value type for XeTile load_tile and store_tile op
def XeTile_2DOr4DVector: VectorOfRankAndType<[2, 4], [XeTile_ScalarType]>;

// define the attribute type allowed for padding values for load op
def XeTile_PaddingValueAttr : AnyAttrOf<[I32Attr, F32Attr]>;



#endif // _XETILE_TYPES_TD_INCLUDED_
