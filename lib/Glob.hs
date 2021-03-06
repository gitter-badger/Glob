




-- lib/GLob.hs

{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE ViewPatterns               #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleInstances          #-}

module Glob where

      import Glob.Config

      import Yesod

      import Database.Persist
      import Database.Persist.TH
      import Database.Persist.Postgresql

      import Data.Aeson

      import Data.Text.Lazy.Encoding(decodeUtf8)

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
        Navs json sql=table_nav
          Id sql=
          text Text sql=texts
          order Int Maybe sql=ordering
          ref Text sql=refto
          Primary text
          deriving Eq Show
        Pages sql=table_pages
          Id sql=
          index Text sql=indexs
          to Text sql=tos
          time Day sql=times
          title Text
          Primary index
          deriving Eq Show
        Blogs sql=table_blogs
          Id sql=
          index Text sql=indexs
          to Text sql=tos
          time Day sql=times
          title Text
          Primary index
          deriving Eq Show
        Htmls sql=table_htmls
          Id sql=
          index Text sql=indexs
          html Text
          title Text
          Primary index
        CSSs sql=table_csss
          Id sql=
          index Text sql=indexs
          css Text
          Primary index
        JSs sql=table_jss
          Id sql=
          index Text sql=indexs
          js Text
          Primary index
      |]




      mkYesod "Glob" [parseRoutes|
      / HomeR GET
      /nav NavR POST
      /page/#Text PageR GET
      /blog BlogListR GET
      /blog/#Text/#Text BlogItemR GET
      /favicon.ico FaviconR GET
      /css/#Text CssR GET
      /js/#Text JsR GET
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
        [Entity _ (Htmls _ mainText mainTitle)] <- liftHandlerT $ runDB $
          selectList [HtmlsIndex ==. "@#page.main"] []
        let mainHtml = preEscapedToHtml mainText
        --setTitle $ toHtml mainTitle
        defaultLayout $ do
          setTitle "Home"
          [whamlet|#{mainHtml}|]
      getBlogItemR :: Text -> Text -> Handler Html
      getBlogItemR time index = do
        [Entity _ (Blogs _ to _ _ )] <- liftHandlerT $ runDB $
          selectList [BlogsTime ==. read (unpack time),BlogsIndex ==. index] []
        [Entity _ (Htmls _ blogText blogTitle)] <- liftHandlerT $ runDB $
          selectList [HtmlsIndex ==. to] []
        let blogHtml = preEscapedToHtml blogText
        defaultLayout $ do
          setTitle $ toHtml blogTitle
          [whamlet|#{blogHtml}|]
      getFaviconR :: Handler Html
      getFaviconR = do
        (Glob _ (Config _ _ path _ _ _)) <- getYesod
        sendFile "applcation/x-ico" path
      getBlogListR :: Handler Html
      getBlogListR = do
        blogs' <- liftHandlerT $ runDB $
          selectList [] [Desc BlogsTime]
        let blogs = map toList blogs'
        defaultLayout $ do
          setTitle "Blog's List"
          [whamlet|
            $if null blogs
              <p> 没有文章
            $else
              <ul>
              $forall (ref,title) <- blogs
                <li>
                  <a href=#{ref}> #{title}
            |]
        where
          toList (Entity _ (Blogs index _ time title)) = ("/blog/"++show time++"/"++unpack index,title)
      getPageR :: Text -> Handler Html
      getPageR index = do
        [Entity _ (Pages _ to _ _ )] <- liftHandlerT $ runDB $
          selectList [PagesIndex ==. index] [ Desc PagesTime]
        [Entity _ (Htmls _ pageText pageTitle)] <- liftHandlerT $ runDB $
          selectList [HtmlsIndex ==. to] []
        let pageHtml = preEscapedToHtml pageText
        --setTitle pageTitle
        defaultLayout $ do
          setTitle $ toHtml pageTitle
          [whamlet|#{pageHtml}|]


      getCssR :: Text -> Handler TypedContent
      getCssR index = do
        [Entity _ (CSSs _ cssText)] <- liftHandlerT $ runDB $ selectList [CSSsIndex ==. index] []
        selectRep $ provideRepType "text/css" $ return cssText

      getJsR :: Text -> Handler TypedContent
      getJsR index = do
        [Entity _ (JSs _ jsText)] <- liftHandlerT $ runDB $ selectList [JSsIndex ==. index] []
        selectRep $ provideRepType "application/x-javascript" $ return jsText


      postNavR :: Handler TypedContent
      postNavR = do
        navs' <- liftHandlerT $ runDB $ selectList [] [Desc NavsOrder]
        let navs = map (\(Entity _ x) -> x) navs'
        selectRep $ provideRepType "application/json" $ return $ decodeUtf8 $ encode navs


      globLayout :: Widget -> Handler Html
      globLayout w = do
        Glob _ (Config _ _ _ ti _ _) <- liftHandlerT getYesod
        pc <- widgetToPageContent w
        [Entity _ (Htmls _ topText _)] <- liftHandlerT $ runDB $ selectList [HtmlsIndex ==. "@#page.frame.top"] []
        [Entity _ (Htmls _ cprightText _)] <- liftHandlerT $ runDB $ selectList [HtmlsIndex ==. "@#page.frame.copyright"] []
        [Entity _ (Htmls _ navText _)] <- liftHandlerT $ runDB $ selectList [HtmlsIndex ==. "@#page.frame.nav"] []
        let topHtml = preEscapedToHtml topText
        let cprightHtml = preEscapedToHtml cprightText
        let navHtml = preEscapedToHtml navText
        let adText = "<h1> 假设这里有广告 </h1>" ::String
        let adHtml = preEscapedToHtml adText
        withUrlRenderer
          [hamlet|
            $newline never
            $doctype 5
            <html>
              <head>
                <title>
                  #{ti} - #{pageTitle pc}
                <meta charset=utf-8>
                ^{pageHead pc}
              <body>
                <link rel=stylesheet href=@{CssR "css.frame.css"}>
                #{topHtml}
                #{navHtml}
                ^{pageBody pc}
                #{cprightHtml}
                #{adHtml}
          |]
