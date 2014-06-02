{-# LANGUAGE Safe #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  $Header$
-- Copyright   :  © 2013-2014 Nicola Squartini
-- License     :  BSD3
--
-- Maintainer  :  Nicola Squartini <tensor5@gmail.com>
-- Stability   :  experimental
-- Portability :  portable
--
-- @linux-xattr@ provides bindings to the Linux syscalls for reading and
-- manipulating extended attributes (@setxattr@, @getxattr@, @listxattr@, ...).
-- Each function in this module has two variants: one with the name prefixed by
-- \"l\" and one prefixed by \"fd\".  Both of these are identical to the
-- original version except that the \"l\"-variant does not follow symbolic link
-- but acts on the link itself, and the \"fd\"-variant take a file descriptor as
-- argument rather than a @'FilePath'@.
--
--------------------------------------------------------------------------------

module System.Linux.XAttr
    ( -- * Set extended attributes
      setXAttr
    , lSetXAttr
    , fdSetXAttr
      -- * Create extended attributes
    , createXAttr
    , lCreateXAttr
    , fdCreateXAttr
      -- * Replace extended attributes
    , replaceXAttr
    , lReplaceXAttr
    , fdReplaceXAttr
      -- * Retrive extended attributes
    , getXAttr
    , lGetXAttr
    , fdGetXAttr
      -- * List extended attributes
    , listXAttr
    , lListXAttr
    , fdListXAttr
      -- * Remove extended attributes
    , removeXAttr
    , lRemoveXAttr
    , fdRemoveXAttr
      -- * Types for extended attributes
    , Name
    , Value
      ) where

#include <sys/xattr.h>

import           Data.ByteString       (ByteString, packCStringLen,
                                        useAsCStringLen)
import           Foreign.C             (CInt (..), CSize (..), CString,
                                        peekCStringLen, throwErrnoIfMinus1,
                                        throwErrnoIfMinus1_, withCString)
import           Foreign.Marshal.Alloc (allocaBytes)
import           Foreign.Ptr           (Ptr, castPtr, nullPtr)
import           System.Posix.Types    (CSsize (..), Fd (..))

-- | Name of extended attribute.
type Name = String

-- | Value of extended attribute.
type Value = ByteString

xAttrSet :: Name
         -> Value
         -> (a -> CString -> Ptr () -> CSize -> CInt -> IO CInt)
         -> String
         -> CInt
         -> a
         -> IO ()
xAttrSet attr value func name mode f =
    throwErrnoIfMinus1_ name $ withCString attr $ \b ->
        useAsCStringLen value $ \(c,d) ->
            func f b (castPtr c) (fromIntegral d) mode

-- | Set the @'Value'@ of the extended attribute identified by @'Name'@ and
-- associated with the given @'FilePath'@ in the filesystem.
setXAttr :: FilePath -> Name -> Value -> IO ()
setXAttr path attr value =
    withCString path $ xAttrSet attr value c_setxattr "setxattr" 0

-- | Set the @'Value'@ of the extended attribute identified by @'Name'@ and
-- associated with the given @'FilePath'@ in the filesystem (do not follow
-- symbolic links).
lSetXAttr :: FilePath -> Name -> Value -> IO ()
lSetXAttr path attr value =
    withCString path $ xAttrSet attr value c_lsetxattr "lsetxattr" 0

-- | Set the @'Value'@ of the extended attribute identified by @'Name'@ and
-- associated with the given file descriptor in the filesystem.
fdSetXAttr :: Fd -> Name -> Value -> IO ()
fdSetXAttr (Fd n) attr value =
    xAttrSet attr value c_fsetxattr "fsetxattr" 0 n

-- | Identical to @'setXAttr'@, but if the attribute already exists fail with
-- @`System.IO.Error.isAlreadyExistsError`@.
createXAttr :: FilePath -> Name -> Value -> IO ()
createXAttr path attr value =
    withCString path $
    xAttrSet attr value c_setxattr "setxattr" #{const XATTR_CREATE}

-- | Identical to @'lSetXAttr'@, but if the attribute already exists fail with
-- @`System.IO.Error.isAlreadyExistsError`@.
lCreateXAttr :: FilePath -> Name -> Value -> IO ()
lCreateXAttr path attr value =
    withCString path $
    xAttrSet attr value c_lsetxattr "lsetxattr" #{const XATTR_CREATE}

-- | Identical to @'fdSetXAttr'@, but if the attribute already exists fail with
-- @`System.IO.Error.isAlreadyExistsError`@.
fdCreateXAttr :: Fd -> Name -> Value -> IO ()
fdCreateXAttr (Fd n) attr value =
    xAttrSet attr value c_fsetxattr "fsetxattr" #{const XATTR_CREATE} n

-- | Identical to @'setXAttr'@, but if the attribute does not exist fail with
-- @`System.IO.Error.isDoesNotExistError`@.
replaceXAttr :: FilePath -> Name -> Value -> IO ()
replaceXAttr path attr value =
    withCString path $
    xAttrSet attr value c_setxattr "setxattr" #{const XATTR_REPLACE}

-- | Identical to @'lSetXAttr'@, but if the attribute does not exist fail with
-- @`System.IO.Error.isDoesNotExistError`@.
lReplaceXAttr :: FilePath -> Name -> Value -> IO ()
lReplaceXAttr path attr value =
    withCString path $
    xAttrSet attr value c_lsetxattr "lsetxattr" #{const XATTR_REPLACE}

-- | Identical to @'fdSetXAttr'@, but if the attribute does not exist fail with
-- @`System.IO.Error.isDoesNotExistError`@.
fdReplaceXAttr :: Fd -> Name -> Value -> IO ()
fdReplaceXAttr (Fd n) attr value =
    xAttrSet attr value c_fsetxattr "fsetxattr" #{const XATTR_REPLACE} n


xAttrGet :: Name
         -> (a -> CString -> Ptr () -> CSize -> IO CSsize)
         -> String
         -> a
         -> IO Value
xAttrGet attr func name f =
    withCString attr $ \cstr ->
        do size <- throwErrnoIfMinus1 name (func f cstr nullPtr 0)
           allocaBytes (fromIntegral size) $ \p ->
               do throwErrnoIfMinus1_ name $ func f cstr p (fromIntegral size)
                  packCStringLen (castPtr p, fromIntegral size)

-- | Get the @'Value'@ of the extended attribute identified by @'Name'@ and
-- associated with the given @'FilePath'@ in the filesystem, or fail with
-- @`System.IO.Error.isDoesNotExistError`@ if the attribute does not exist.
getXAttr :: FilePath -> Name -> IO Value
getXAttr path attr =
    withCString path $ xAttrGet attr c_getxattr "getxattr"

-- | Get the @'Value'@ of the extended attribute identified by @'Name'@ and
-- associated with the given @'FilePath'@ in the filesystem, or fail with
-- @`System.IO.Error.isDoesNotExistError`@ if the attribute does not exist (do
-- not follow symbolic links).
lGetXAttr :: FilePath -> Name -> IO Value
lGetXAttr path attr =
    withCString path $ xAttrGet attr c_lgetxattr "lgetxattr"

-- | Get the @'Value'@ of the extended attribute identified by @'Name'@ and
-- associated with the given file descriptor in the filesystem, or fail with
-- @`System.IO.Error.isDoesNotExistError`@ if the attribute does not exist.
fdGetXAttr :: Fd -> Name -> IO Value
fdGetXAttr (Fd n) attr =
    xAttrGet attr c_fgetxattr "fgetxattr" n


xAttrList :: (a -> CString -> CSize -> IO CSsize)
          -> String
          -> a
          -> IO [Name]
xAttrList func name f =
    do size <- throwErrnoIfMinus1 name (func f nullPtr 0)
       allocaBytes (fromIntegral size) $ \p ->
           do throwErrnoIfMinus1_ name (func f p (fromIntegral size))
              str <- peekCStringLen (p, fromIntegral size)
              return $ split str
    where split "" = []
          split xs = fst c : split (tail $ snd c)
              where c = break (== '\NUL') xs

-- | Get the list of extended attribute @'Name'@s associated with the given
-- @'FilePath'@ in the filesystem.
listXAttr :: FilePath -> IO [Name]
listXAttr path = withCString path $ xAttrList c_listxattr "listxattr"

-- | Get the list of extended attribute @'Name'@s associated with the given
-- @'FilePath'@ in the filesystem (do not follow symbolic links).
lListXAttr :: FilePath -> IO [Name]
lListXAttr path =
    withCString path $ xAttrList c_llistxattr "llistxattr"

-- | Get the list of extended attribute @'Name'@s associated with the given file
-- descriptor in the filesystem.
fdListXAttr :: Fd -> IO [Name]
fdListXAttr (Fd n) =
    xAttrList c_flistxattr "flistxattr" n


xAttrRemove :: Name -> (a -> CString -> IO CInt) -> String -> a -> IO ()
xAttrRemove attr func name f =
    throwErrnoIfMinus1_ name $ withCString attr (func f)

-- | Remove the extended attribute identified by @'Name'@ and associated with
-- the given @'FilePath'@ in the filesystem, or fail with
-- @`System.IO.Error.isDoesNotExistError`@ if the attribute does not exist.
removeXAttr :: FilePath -> Name -> IO ()
removeXAttr path attr =
    withCString path $ xAttrRemove attr c_removexattr "removexattr"

-- | Remove the extended attribute identified by @'Name'@ and associated with
-- the given @'FilePath'@ in the filesystem, or fail with
-- @`System.IO.Error.isDoesNotExistError`@ if the attribute does not exist (do
-- not follow symbolic links).
lRemoveXAttr :: FilePath -> Name -> IO ()
lRemoveXAttr path attr =
    withCString path $ xAttrRemove attr c_lremovexattr "lremovexattr"

-- | Remove the extended attribute identified by @'Name'@ and associated with
-- the given file descriptor in the filesystem, or fail with
-- @`System.IO.Error.isDoesNotExistError`@ if the attribute does not exist.
fdRemoveXAttr :: Fd -> Name -> IO ()
fdRemoveXAttr (Fd n) attr =
    xAttrRemove attr c_fremovexattr "fremovexattr" n


foreign import ccall unsafe "setxattr" c_setxattr :: CString
                                                  -> CString
                                                  -> Ptr ()
                                                  -> CSize
                                                  -> CInt
                                                  -> IO CInt

foreign import ccall unsafe "lsetxattr" c_lsetxattr :: CString
                                                    -> CString
                                                    -> Ptr ()
                                                    -> CSize
                                                    -> CInt
                                                    -> IO CInt

foreign import ccall unsafe "fsetxattr" c_fsetxattr :: CInt
                                                    -> CString
                                                    -> Ptr ()
                                                    -> CSize
                                                    -> CInt
                                                    -> IO CInt


foreign import ccall unsafe "getxattr" c_getxattr :: CString
                                                  -> CString
                                                  -> Ptr ()
                                                  -> CSize
                                                  -> IO CSsize

foreign import ccall unsafe "lgetxattr" c_lgetxattr :: CString
                                                    -> CString
                                                    -> Ptr ()
                                                    -> CSize
                                                    -> IO CSsize

foreign import ccall unsafe "fgetxattr" c_fgetxattr :: CInt
                                                    -> CString
                                                    -> Ptr ()
                                                    -> CSize
                                                    -> IO CSsize


foreign import ccall unsafe "listxattr" c_listxattr :: CString
                                                    -> CString
                                                    -> CSize
                                                    -> IO CSsize

foreign import ccall unsafe "llistxattr" c_llistxattr :: CString
                                                      -> CString
                                                      -> CSize
                                                      -> IO CSsize

foreign import ccall unsafe "flistxattr" c_flistxattr :: CInt
                                                      -> CString
                                                      -> CSize
                                                      -> IO CSsize


foreign import ccall unsafe "removexattr" c_removexattr :: CString
                                                        -> CString
                                                        -> IO CInt

foreign import ccall unsafe "lremovexattr" c_lremovexattr :: CString
                                                          -> CString
                                                          -> IO CInt

foreign import ccall unsafe "fremovexattr" c_fremovexattr :: CInt
                                                          -> CString
                                                          -> IO CInt
