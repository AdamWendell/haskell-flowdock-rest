{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
module Chat.Flowdock.REST.Message (
  -- * Message
  Message(..),
  msgContent,
  msgTags,
  msgCreatedAt,
  msgEditedAt,
  msgFlowId,
  msgId,
  -- * Content
  MessageContent(..),
  -- * Comment
  Comment(..),
  commentText,
  commentTitle,
  -- * Mail
  Mail(..),
  mailSubject,
  mailContent,
  MailAddress(..),
  mailAddress,
  mailAddressName,
  ) where

import Data.Aeson

import Control.Applicative
import Control.DeepSeq
import Control.Lens
import Data.Aeson
import Data.Hashable
import Data.Monoid
import Data.Text as T
import Data.Time
import GHC.Generics

import Chat.Flowdock.REST.Internal
import Chat.Flowdock.REST.Organisation
import Chat.Flowdock.REST.Pretty

data Comment = Comment
  { _commentText  :: !Text
  , _commentTitle :: !Text
  }
  deriving (Eq, Ord, Show, Generic)

makeLenses ''Comment

instance NFData Comment
instance Hashable Comment

instance FromJSON Comment where
  parseJSON = withObject "Commnet" $ \obj ->
    Comment <$> obj .: "text"
            <*> obj .: "title"

instance Pretty Comment where
  pretty Comment {..} = prettyRecord "Comment"
    [ prettyField "text" (T.unpack _commentText)
    , prettyField "title" (T.unpack _commentTitle)
    ]


data MailAddress = MailAddress
  { _mailAddress     :: !Text
  , _mailAddressName :: !(Maybe Text)
  }
  deriving (Eq, Ord, Show, Generic)

makeLenses ''MailAddress

instance NFData MailAddress
instance Hashable MailAddress

instance FromJSON MailAddress where
  parseJSON = withObject "MailAddress" $ \obj ->
    MailAddress <$> obj .: "address"
                <*> obj .:? "name"

instance Pretty MailAddress where
  pretty (MailAddress addr Nothing)     = text . T.unpack $ addr
  pretty (MailAddress addr (Just name)) = text . T.unpack $ name <> " <" <> addr <> ">"


data Mail = Mail
  { _mailSubject :: !Text
  , _mailContent :: !Text
  , _mailTo      :: ![MailAddress]
  , _mailFrom    :: ![MailAddress]
  , _mailCc      :: ![MailAddress]
  , _mailBcc     :: ![MailAddress]
  , _mailReplyTo :: ![MailAddress]
  }
  deriving (Eq, Ord, Show, Generic)

makeLenses ''Mail

instance NFData Mail
instance Hashable Mail

instance FromJSON Mail where
  parseJSON = withObject "Mail" $ \obj ->
    Mail <$> obj .: "subject"
         <*> obj .: "content"
         <*> obj .: "to"
         <*> obj .: "from"
         <*> obj .: "cc"
         <*> obj .: "bcc"
         <*> obj .: "replyTo"

instance Pretty Mail where
  pretty Mail {..} = prettyRecord "Mail"
    [ prettyField "subject" (T.unpack _mailSubject)
    , prettyField "to" _mailTo
    , prettyField "from" _mailFrom
    -- , prettyField "content" (T.unpack _mailContent) -- Let's omit content for brevity
    ]

data MessageContent = MTMessage String
                    | MTStatus
                    | MTComment Comment
                    | MTAction
                    | MTTagChange
                    | MTMessageEdit
                    | MTActivityUser
                    | MTFile Value
                    | MTMail Mail
                    | MTActivity
                    | MTDiscussion Value
  deriving (Eq, Show, Generic)

instance NFData MessageContent
instance Hashable MessageContent

makeLenses ''MessageContent

instance FromJSON MessageContent where
  parseJSON = withObject "Message" $ \obj -> do
    event <- obj .: "event"
    content <- obj .: "content"
    case event of
      "message" -> MTMessage <$> parseJSON content
      "comment" -> MTComment <$> parseJSON content
      "file"    -> pure $ MTFile content
      "mail"    -> MTMail <$> parseJSON content
      _         -> fail $ "Invalid message type: " <> event


instance Pretty MessageContent where
  pretty (MTMessage msg) = text "message:" <+> text msg
  pretty (MTComment com) = pretty com
  pretty (MTMail mail)   = pretty mail
  pretty m = text . show $ m

data Message = Message
  { _msgContent    :: !MessageContent
  , _msgTags       :: ![Text]
  , _msgCreatedAt  :: !UTCTime
  , _msgEditedAt   :: !(Maybe UTCTime)
  , _msgFlowId     :: !FlowId
  , _msgId         :: !MessageId
  }
  deriving (Eq, Show, Generic)

makeLenses ''Message

instance NFData Message
-- instance Hashable Message

instance FromJSON Message where
  parseJSON v = do
    content <- parseJSON v
    flip (withObject "Message") v $ \obj ->
      Message <$> pure content
              <*> obj .: "tags"
              <*> obj .: "created_at"
              <*> obj .:? "edited_at"
              <*> obj .: "flow"
              <*> obj .: "id"

instance Pretty Message where
  pretty Message {..} = text "Message" </> semiBraces
    [ prettyField "id" _msgId
    , prettyField "flow" _msgFlowId
    , prettyField "tags" (T.unpack <$> _msgTags)
    , prettyField "content" _msgContent
    ]