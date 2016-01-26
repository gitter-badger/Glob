




-- lib/GLob.hs

{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE ViewPatterns               #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Glob where

      import Glob.Config

      import Yesod

      import Database.Persist
      import Database.Persist.TH
      import Database.Persist.Postgresql

      import Data.Text.Lazy hiding(null,map)

      import Data.List
      import Data.Time

      import Text.Blaze.Html



      data Glob = Glob
        { conPool :: ConnectionPool
        , config :: Config
        }

      instance YesodPersist Glob where
        type YesodPersistBackend Glob = SqlBackend
        runDB a = do
          (Glob p _) <- getYesod
          runSqlPool a p






      share [mkPersist sqlSettings,mkMigrate "migrateAll"] [persistLowerCase|
        Navs sql=table_nav
          Id sql=
          text Text
          order Int Maybe
          ref Text
          Primary text
          deriving Eq Show
        Pages sql=table_pages
          Id sql=
          index Text
          to Text
          time Day
          title Text
          Primary index
          deriving Eq Show
        Blogs sql=table_blogs
          Id sql=
          index Text
          to Text
          time Day
          title Text
          Primary index
          deriving Eq Show
        Htmls sql=table_htmls
          Id sql=
          index Text
          html Text
          Primary index
      |]




      mkYesod "Glob" [parseRoutes|
      / HomeR GET
      /page/#Text PageR GET
      /blog BlogListR GET
      /blog/#Text/#Text BlogItemR GET
      /favicon.ico FaviconR GET
      |]

      instance Yesod Glob where
        errorHandler NotFound = selectRep $ provideRep $ defaultLayout [whamlet|NotFound-404|]
        errorHandler NotAuthenticated = selectRep $ provideRep $ defaultLayout [whamlet|NotAuthenticated|]
        errorHandler (PermissionDenied x) = selectRep $ provideRep $ defaultLayout [whamlet|
          PermissionDenied
          <br>
          #{x}
          |]
        errorHandler (InvalidArgs x) = selectRep $ provideRep $ defaultLayout [whamlet|
          InvalidArgs
          <br>
          #{show x}
          |]
        errorHandler (BadMethod x) = selectRep $ provideRep $ defaultLayout [whamlet|
          BadMethod
          <br>
          #{show x}
          |]
        errorHandler (InternalError x) = selectRep $ provideRep $ defaultLayout [whamlet|
          InternalError
          <br>
          #{x}
          |]
        isAuthorized _ _ = return Authorized
        defaultLayout = globLayout

      getHomeR :: Handler Html
      getHomeR = do
        [Entity _ (Htmls _ mainText)] <- liftHandlerT $ runDB $
          selectList [HtmlsIndex ==. "@#page.main"] []
        let mainHtml = preEscapedToHtml mainText
        defaultLayout [whamlet|#{mainHtml}|]
      getBlogItemR :: Text -> Text -> Handler Html
      getBlogItemR time index = do
        [Entity _ (Blogs _ to _ _ )] <- liftHandlerT $ runDB $
          selectList [BlogsTime ==. read (unpack time),BlogsIndex ==. index] []
        [Entity _ (Htmls _ blogText)] <- liftHandlerT $ runDB $
          selectList [HtmlsIndex ==. to] []
        let blogHtml = preEscapedToHtml blogText
        defaultLayout [whamlet|#{blogHtml}|]
      getFaviconR :: Handler Html
      getFaviconR = do
        (Glob _ (Config _ _ path)) <- getYesod
        sendFile "applcation/x-ico" path
      getBlogListR :: Handler Html
      getBlogListR = do
        blogs' <- liftHandlerT $ runDB $
          selectList [] [Desc BlogsTime]
        let blogs = map toList blogs'
        defaultLayout [whamlet|
        $if null blogs
          <p> 没有文章
        $else
          <ul>
            $forall (ref,title) <- blogs
              <li>
                <a href=#{ref}>
                  #{title}
        |]
        where
          toList (Entity _ (Blogs index _ time title)) = ("/blog/"++show time++"/"++unpack index,title)
      getPageR :: Text -> Handler Html
      getPageR index = do
        [Entity _ (Pages _ to _ _ )] <- liftHandlerT $ runDB $
          selectList [PagesIndex ==. index] [ Desc PagesTime]
        [Entity _ (Htmls _ pageText)] <- liftHandlerT $ runDB $
          selectList [HtmlsIndex ==. to] []
        let pageHtml = preEscapedToHtml pageText
        defaultLayout [whamlet|#{pageHtml}|]






      globLayout :: Widget -> Handler Html
      globLayout w = do
        pc <- widgetToPageContent w
        [Entity _ (Htmls _ topText)] <- liftHandlerT $ runDB $ selectList [HtmlsIndex ==. "@#page.frame.top"] []
        [Entity _ (Htmls _ cprightText)] <- liftHandlerT $ runDB $ selectList [HtmlsIndex ==. "@#page.frame.copyright"] []
        navs' <- liftHandlerT $ runDB $ selectList [NavsOrder !=. Nothing] []
        let navs = sortOn (\(Navs _ x _) -> x) $ map (\(Entity _ x) -> x) navs'
        let topHtml = preEscapedToHtml topText
        let cprightHtml = preEscapedToHtml cprightText
        let adText = "<h1> 假设这里有广告 </h1>" ::String
        let adHtml = preEscapedToHtml adText
        withUrlRenderer
          [hamlet|
            $doctype 5
            <html>
              <head>
                <title>#{pageTitle pc }
                <meta charset=utf-8>
                ^{pageHead pc}
              <body>
                #{topHtml}
                <div>
                  $if null navs
                    <p> Nothing
                  $else
                    <ul>
                      $forall nav <- navs
                       <li>
                        <a href=#{navsRef nav}> #{navsText nav}
                ^{pageBody pc}
                #{cprightHtml}
                #{adHtml}
          |]