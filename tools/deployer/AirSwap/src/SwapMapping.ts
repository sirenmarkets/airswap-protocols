import { BigInt, log } from "@graphprotocol/graph-ts"
import {
  AuthorizeSender,
  AuthorizeSigner,
  Cancel,
  CancelUpTo,
  RevokeSender,
  RevokeSigner,
  Swap
} from "../generated/SwapContract/SwapContract"
import { SwapContract, ExecutedOrder } from "../generated/schema"
import { getUser, getToken } from "./EntityHelper"

export function handleAuthorizeSender(event: AuthorizeSender): void {
  let authorizer = getUser(event.params.authorizerAddress.toHex())
  let sender = getUser(event.params.authorizedSender.toHex())

  let authorizedSenders = authorizer.authorizedSenders
  let currentIdx = authorizedSenders.indexOf(sender.id)
  // only add if sender is not in the list
  if (currentIdx == -1) {
    authorizedSenders.push(sender.id)
    authorizer.authorizedSenders = authorizedSenders
    authorizer.save()
  }
}

export function handleRevokeSender(event: RevokeSender): void {
  let deauthorizer = getUser(event.params.authorizerAddress.toHex())
  let revokedSender = getUser(event.params.revokedSender.toHex())

  let authorizedSenders = deauthorizer.authorizedSenders
  let idxToRemove = authorizedSenders.indexOf(revokedSender.id)
  // only remove if the revokedSender exists
  if (idxToRemove > -1) {
    authorizedSenders.splice(idxToRemove, 1);
    deauthorizer.authorizedSenders = authorizedSenders
    deauthorizer.save()
  }
}

export function handleAuthorizeSigner(event: AuthorizeSigner): void {
  let authorizer = getUser(event.params.authorizerAddress.toHex())
  let signer = getUser(event.params.authorizedSigner.toHex())

  let authorizedSigners = authorizer.authorizedSigners
  let currentIdx = authorizedSigners.indexOf(signer.id)
  // only add if signer is not in the list
  if (currentIdx == -1) {
    authorizedSigners.push(signer.id)
    authorizer.authorizedSigners = authorizedSigners
    authorizer.save()
  }
}

export function handleRevokeSigner(event: RevokeSigner): void {
  let deauthorizer = getUser(event.params.authorizerAddress.toHex())
  let revokedSigner = getUser(event.params.revokedSigner.toHex())

  // handle removal
  let authorizedSigners = deauthorizer.authorizedSigners
  let idxToRemove = authorizedSigners.indexOf(revokedSigner.id)
  // only remove if the revokedSigner exists
  if (idxToRemove > -1) {
    authorizedSigners.splice(idxToRemove, 1);
    deauthorizer.authorizedSigners = authorizedSigners
    deauthorizer.save()
  }
}

export function handleCancel(event: Cancel): void {
  let user = getUser(event.params.signerWallet.toHex())
  let cancelledNonces = user.cancelledNonces
  cancelledNonces.push(event.params.nonce)
  cancelledNonces.sort()
  user.cancelledNonces = cancelledNonces
  user.save()
}

export function handleCancelUpTo(event: CancelUpTo): void {
  let user = getUser(event.params.signerWallet.toHex())
  let cancelledNonces = user.cancelledNonces
  for (let i = BigInt.fromI32(0); i.lt(event.params.nonce); i = i.plus(BigInt.fromI32(1))) {
    // prevent duplicates
    if (cancelledNonces.indexOf(i) > -1) {
      continue
    }
    cancelledNonces.push(i)
  }
  cancelledNonces.sort()
  user.cancelledNonces = cancelledNonces
  user.save()
}

export function handleSwap(event: Swap): void {
  let executedOrder = new ExecutedOrder(event.params.signerWallet.toHex() + event.params.nonce.toString())

  // create swap contract if it doesn't exist
  var swap = SwapContract.load(event.address.toHex())
  if (!swap) {
    swap = new SwapContract(event.address.toHex())
    swap.save()
  }

  var signer = getUser(event.params.signerWallet.toHex())
  var sender = getUser(event.params.senderWallet.toHex())
  var affiliate = getUser(event.params.affiliateWallet.toHex())
  var signerToken = getToken(event.params.signerToken.toHex())
  var senderToken = getToken(event.params.senderToken.toHex())
  var affiliateToken = getToken(event.params.senderToken.toHex())

  executedOrder.swap = swap.id
  executedOrder.from = event.transaction.from
  executedOrder.to = event.transaction.to
  executedOrder.value = event.transaction.value

  executedOrder.nonce = event.params.nonce
  executedOrder.expiry = event.params.timestamp

  executedOrder.signer = signer.id
  executedOrder.signerAmount = event.params.signerAmount
  executedOrder.signerTokenType = event.params.signerId
  executedOrder.signerToken = signerToken.id

  executedOrder.sender = sender.id
  executedOrder.senderAmount = event.params.senderAmount
  executedOrder.senderTokenType = event.params.senderId
  executedOrder.senderToken = senderToken.id

  executedOrder.affiliate = affiliate.id
  executedOrder.affiliateAmount = event.params.affiliateAmount
  executedOrder.affiliateTokenType = event.params.affiliateId
  executedOrder.affiliateToken = affiliateToken.id

  executedOrder.save()
}
