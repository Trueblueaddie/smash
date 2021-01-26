{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

-- Need this because both ghc-8.6.5 and ghc-8.10.2 incorrectly warns about a redundant constraint
-- in the definition of renderAddress.
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module Cardano.Sync.Era.Shelley.Generic.Util
  ( annotateStakingCred
  --, coinToDbLovelace
  , maybePaymentCred
  --, mkSlotLeader
  , nonceToBytes
  , renderAddress
  , renderRewardAcnt
  , stakingCredHash
  , unitIntervalToDouble
  , unKeyHashRaw
  , unKeyHashView
  , unScriptHash
  , unTxHash
  ) where

import           Cardano.Prelude

import qualified Cardano.Api.Shelley as Api
import qualified Cardano.Api.Typed as Api

import qualified Cardano.Crypto.Hash as Crypto

import           Cardano.Sync.Config

import           Cardano.Ledger.Crypto ()

import qualified Data.Binary.Put as Binary
import qualified Data.ByteString.Lazy.Char8 as LBS

import           Ouroboros.Consensus.Cardano.Block (StandardAllegra, StandardCrypto, StandardMary,
                   StandardShelley)

import qualified Shelley.Spec.Ledger.Address as Shelley
import qualified Shelley.Spec.Ledger.BaseTypes as Shelley
import qualified Shelley.Spec.Ledger.Credential as Shelley
import qualified Shelley.Spec.Ledger.Keys as Shelley
import qualified Shelley.Spec.Ledger.Scripts as Shelley
import qualified Shelley.Spec.Ledger.Tx as Shelley


annotateStakingCred :: DbSyncEnv -> Shelley.StakeCredential era -> Shelley.RewardAcnt era
annotateStakingCred env cred =
  let network =
        case envProtocol env of
          DbSyncProtocolCardano -> envNetwork env
  in Shelley.RewardAcnt network cred

maybePaymentCred :: Shelley.Addr era -> Maybe ByteString
maybePaymentCred addr =
  case addr of
    Shelley.Addr _nw pcred _sref ->
      Just $ LBS.toStrict (Binary.runPut $ Shelley.putCredential pcred)
    Shelley.AddrBootstrap {} ->
      Nothing

nonceToBytes :: Shelley.Nonce -> Maybe ByteString
nonceToBytes nonce =
  case nonce of
    Shelley.Nonce hash -> Just $ Crypto.hashToBytes hash
    Shelley.NeutralNonce -> Nothing

type family LedgerEraToApiEra ledgerera where
  LedgerEraToApiEra StandardShelley = Api.ShelleyEra
  LedgerEraToApiEra StandardAllegra = Api.AllegraEra
  LedgerEraToApiEra StandardMary = Api.MaryEra

renderAddress
    :: forall ledgerera era. Api.IsCardanoEra era
    => LedgerEraToApiEra ledgerera ~ era
    => Api.ShelleyLedgerEra era ~ ledgerera
    => Api.IsShelleyBasedEra era
    => Shelley.Addr ledgerera -> Text
renderAddress addr = Api.serialiseAddress (Api.fromShelleyAddr addr :: Api.AddressInEra era)

renderRewardAcnt :: Shelley.RewardAcnt era -> Text
renderRewardAcnt = Api.serialiseAddress . Api.fromShelleyStakeAddr

stakingCredHash :: DbSyncEnv -> Shelley.StakeCredential era -> ByteString
stakingCredHash env = Shelley.serialiseRewardAcnt . annotateStakingCred env

unitIntervalToDouble :: Shelley.UnitInterval -> Double
unitIntervalToDouble = fromRational . Shelley.unitIntervalToRational

unKeyHashRaw :: Shelley.KeyHash d era -> ByteString
unKeyHashRaw (Shelley.KeyHash kh) = Crypto.hashToBytes kh

unKeyHashView :: Shelley.KeyHash 'Shelley.StakePool StandardCrypto -> Text
unKeyHashView = Api.serialiseToBech32 . Api.StakePoolKeyHash

unScriptHash :: Shelley.ScriptHash StandardShelley -> ByteString
unScriptHash (Shelley.ScriptHash h) = Crypto.hashToBytes h

unTxHash :: Shelley.TxId era -> ByteString
unTxHash (Shelley.TxId txid) = Crypto.hashToBytes txid
