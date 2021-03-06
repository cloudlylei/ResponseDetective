//
// ResponseDetective.swift
//
// Copyright (c) 2016 Netguru Sp. z o.o. All rights reserved.
// Licensed under the MIT License.
//

import Foundation

/// ResponseDetective configuration cluster class that defines the behavior
/// of request interception and logging.
@objc(RDTResponseDetective) public final class ResponseDetective: NSObject {
	
	/// An output facility for reporting requests, responses and errors.
	public static var outputFacility: OutputFacility = ConsoleOutputFacility()
	
	/// A class of the URL protocol used to intercept requests.
	public static let URLProtocolClass: NSURLProtocol.Type = URLProtocol.self
	
	/// A storage for request predicates.
	private static var requestPredicates: [NSPredicate] = []

	/// Body deserializers stored by a supported content type.
	private static var customBodyDeserializers: [String: BodyDeserializer] = [:]

	/// Default body deserializers provided by ResponseDetective.
	private static let defaultBodyDeserializers: [String: BodyDeserializer] = [
		"*/json": JSONBodyDeserializer(),
		"*/xml": XMLBodyDeserializer(),
		"*/html": HTMLBodyDeserializer(),
		"image/*": ImageBodyDeserializer(),
		"text/plain": PlaintextBodyDeserializer(),
	]
	
	/// Resets the ResponseDetective mutable state.
	public static func reset() {
		outputFacility = ConsoleOutputFacility()
		requestPredicates = []
		customBodyDeserializers = [:]
	}

	/// Enables ResponseDetective in an URL session configuration.
	///
	/// - Parameters configuration: The URL session configuration to enable the
	///   session in.
	public static func enableInURLSessionConfiguration(configuration: NSURLSessionConfiguration) {
		configuration.protocolClasses?.insert(URLProtocolClass, atIndex: 0)
	}
	
	/// Ignores requests matching the given predicate. The predicate will be
	/// evaluated with an instance of NSURLRequest.
	///
	/// - Parameter predicate: A predicate for matching a request. If the
	///   predicate evaluates to `false`, the request is not intercepted.
	public static func ignoreRequestsMatchingPredicate(predicate: NSPredicate) {
		requestPredicates.append(predicate)
	}
	
	/// Checks whether the given request can be incercepted.
	///
	/// - Parameter request: The request to check.
	///
	/// - Returns: `true` if request can be intercepted, `false` otherwise.
	public static func canIncerceptRequest(request: NSURLRequest) -> Bool {
		return requestPredicates.reduce(true) {
			return $0 && !$1.evaluateWithObject(request)
		}
	}
	
	/// Registers a body deserializer.
	///
	/// - Parameters:
	///     - deserializer: The deserializer to register.
	///     - contentType: The supported content type.
	public static func registerBodyDeserializer(deserializer: BodyDeserializer, forContentType contentType: String) {
		customBodyDeserializers[contentType] = deserializer
	}
	
	/// Registers a body deserializer.
	///
	/// - Parameters:
	///     - deserializer: The deserializer to register.
	///     - contentTypes: The supported content types.
	public static func registerBodyDeserializer(deserializer: BodyDeserializer, forContentTypes contentTypes: [String]) {
		for contentType in contentTypes {
			registerBodyDeserializer(deserializer, forContentType: contentType)
		}
	}

	/// Finds a body deserializer by pattern.
	///
	/// - Parameter contentType: The content type to find a deserializer for.
	///
	/// - Returns: A body deserializer for given `contentType` or `nil`.
	private static func findBodyDeserializerForContentType(contentType: String) -> BodyDeserializer? {
		for (pattern, deserializer) in defaultBodyDeserializers.appendingElementsOf(dictionary: customBodyDeserializers) {
			let patternParts = pattern.componentsSeparatedByString("/")
			let actualParts = contentType.componentsSeparatedByString("/")
			guard patternParts.count == 2 && actualParts.count == 2 else {
				return nil
			}
			if ["*" , actualParts[0]].contains(patternParts[0]) && ["*" , actualParts[1]].contains(patternParts[1]) {
				return deserializer
			}
		}
		return nil
	}
	
	/// Deserializes a HTTP body into a string.
	///
	/// - Parameters:
	///     - body: The body to deserialize.
	///     - contentType: The content type of the body.
	///
	/// - Returns: A deserialized body or `nil` if no serializer is capable of
	///   deserializing body with the given content type.
	public static func deserializeBody(body: NSData, contentType: String) -> String? {
		if let deserializer = findBodyDeserializerForContentType(contentType) {
			return deserializer.deserializeBody(body)
		} else {
			return nil
		}
	}
	
}
