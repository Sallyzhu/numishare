<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:res="http://www.w3.org/2005/sparql-results#"
	xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:mets="http://www.loc.gov/METS/" xmlns:numishare="https://github.com/ewg118/numishare"
	xmlns:nm="http://nomisma.org/id/" xmlns:nmo="http://nomisma.org/ontology#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:skos="http://www.w3.org/2004/02/skos/core#" xmlns:nuds="http://nomisma.org/nuds" exclude-result-prefixes="#all" version="2.0">
	<xsl:include href="../../functions.xsl"/>

	<!-- variables -->
	<xsl:variable name="recordType" select="//nuds:nuds/@recordType"/>
	<xsl:variable name="lang">en</xsl:variable>
	<xsl:variable name="id" select="normalize-space(//*[local-name() = 'recordId'])"/>
	<xsl:variable name="url" select="/content/config/url"/>
	<xsl:variable name="manifestUri" select="concat($url, 'manifest/', $id)"/>
	<xsl:variable name="objectUri"
		select="
			if (/content/config/uri_space) then
				concat(/content/config/uri_space, $id)
			else
				concat($url, 'id/', $id)"/>

	<!-- read other manifest URI patterns -->
	<xsl:variable name="pieces" select="tokenize(substring-after(doc('input:request')/request/request-url, 'manifest/'), '/')"/>

	<xsl:variable name="nudsGroup" as="element()*">
		<nudsGroup>
			<xsl:choose>
				<xsl:when test="descendant::nuds:typeDesc[string(@xlink:href)]">
					<xsl:variable name="uri" select="descendant::nuds:typeDesc/@xlink:href"/>

					<object xlink:href="{$uri}">
						<xsl:if test="doc-available(concat($uri, '.xml'))">
							<xsl:copy-of select="document(concat($uri, '.xml'))/nuds:nuds"/>
						</xsl:if>
					</object>
				</xsl:when>
				<xsl:otherwise>
					<object>
						<xsl:copy-of select="descendant::nuds:typeDesc"/>
					</object>
				</xsl:otherwise>
			</xsl:choose>
		</nudsGroup>
	</xsl:variable>

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$pieces[2] = 'sequence'">
				<xsl:variable name="model" as="element()*">
					<_object>
						<xsl:call-template name="sequences"/>
					</_object>
				</xsl:variable>
				<xsl:apply-templates select="$model"/>
			</xsl:when>
			<xsl:when test="$pieces[2] = 'canvas'">
				<xsl:variable name="side" select="$pieces[3]"/>

				<xsl:variable name="model" as="element()*">
					<xsl:apply-templates select="//descendant::mets:fileGrp[@USE = $side]/mets:file[@USE = 'iiif']"/>
				</xsl:variable>
				<xsl:apply-templates select="$model"/>
			</xsl:when>
			<xsl:when test="$pieces[2] = 'annotation'">
				<xsl:variable name="side" select="$pieces[3]"/>

				<xsl:variable name="model" as="element()*">
					<xsl:apply-templates select="//descendant::mets:fileGrp[@USE = $side]/mets:file[@USE = 'iiif']/mets:FLocat">
						<xsl:with-param name="side" select="$side"/>
					</xsl:apply-templates>
				</xsl:variable>
				<xsl:apply-templates select="$model"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="//nuds:nuds"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="nuds:nuds">
		<!-- construct XML-JSON metamodel inspired by the XForms JSON-XML serialization -->
		<xsl:variable name="model" as="element()*">
			<_object>
				<__context>http://iiif.io/api/presentation/2/context.json</__context>
				<__id>
					<xsl:value-of select="$manifestUri"/>
				</__id>
				<__type>sc:Manifest</__type>
				<attribution>
					<xsl:value-of select="/content/config/template/agencyName"/>
				</attribution>
				<label>
					<xsl:value-of select="//nuds:descMeta/nuds:title[@xml:lang = 'en']"/>
				</label>

				<!-- generate description from obverse and reverse -->
				<xsl:if test="$nudsGroup//nuds:typeDesc/nuds:obverse or $nudsGroup//nuds:typeDesc/nuds:reverse">
					<description>
						<xsl:apply-templates select="$nudsGroup//nuds:typeDesc/nuds:obverse | $nudsGroup//nuds:typeDesc/nuds:reverse"/>
					</description>
				</xsl:if>

				<!-- extract metadata from descMeta -->
				<metadata>
					<_array>
						<xsl:apply-templates select="$nudsGroup//nuds:typeDesc | nuds:descMeta/nuds:physDesc | nuds:descMeta/nuds:adminDesc"/>
					</_array>
				</metadata>

				<rendering>
					<_object>
						<__id>
							<xsl:value-of select="$objectUri"/>
						</__id>
						<format>text/html</format>
						<label>Full record</label>
					</_object>
				</rendering>

				<seeAlso>
					<_array>
						<_object>
							<__id>
								<xsl:value-of select="concat($objectUri, '.rdf')"/>
							</__id>
							<format>application/rdf+xml</format>
						</_object>
						<_object>
							<__id>
								<xsl:value-of select="concat($objectUri, '.ttl')"/>
							</__id>
							<format>text/turtle</format>
						</_object>
						<_object>
							<__id>
								<xsl:value-of select="concat($objectUri, '.jsonld')"/>
							</__id>
							<format>application/ld+json</format>
						</_object>
					</_array>
				</seeAlso>
				<xsl:call-template name="sequences"/>
				<within>
					<xsl:value-of select="$url"/>
				</within>
			</_object>
		</xsl:variable>

		<xml>
			<xsl:copy-of select="doc('input:images')/*"/>
			<xsl:apply-templates select="$model"/>
			
		</xml>
		
	</xsl:template>

	<!-- XSLT templates for rendering the $model into JSON -->
	<xsl:template match="*">
		<xsl:choose>
			<xsl:when test="child::_array">
				<xsl:value-of select="concat('&#x022;', name(), '&#x022;')"/>
				<xsl:text>:</xsl:text>
				<xsl:apply-templates select="_array"/>
			</xsl:when>
			<xsl:when test="child::_object">
				<xsl:value-of select="concat('&#x022;', name(), '&#x022;')"/>
				<xsl:text>:</xsl:text>
				<xsl:apply-templates select="_object"/>
			</xsl:when>
			<xsl:otherwise>
				<!-- when the element is preceded by two underscores, prepend an @ character, e.g., for @id or @type -->
				<xsl:choose>
					<xsl:when test="substring(name(), 1, 2) = '__'">
						<xsl:value-of select="concat('&#x022;@', substring(name(), 3), '&#x022;')"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="concat('&#x022;', name(), '&#x022;')"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text>:</xsl:text>
				<xsl:call-template name="numishare:evaluateDatatype">
					<xsl:with-param name="val" select="."/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
		<xsl:if test="not(position() = last())">
			<xsl:text>,</xsl:text>
		</xsl:if>
	</xsl:template>

	<!-- object template -->
	<xsl:template match="_object">
		<xsl:text>{</xsl:text>
		<xsl:apply-templates/>
		<xsl:text>}</xsl:text>
		<xsl:if test="not(position() = last())">
			<xsl:text>,</xsl:text>
		</xsl:if>
	</xsl:template>

	<!-- array template -->
	<xsl:template match="_array">
		<xsl:text>[</xsl:text>
		<xsl:apply-templates/>
		<xsl:text>]</xsl:text>
	</xsl:template>

	<!-- XSLT templates to generate XML-JSON metamodel from NUDS -->
	<xsl:template match="nuds:typeDesc">
		<xsl:apply-templates select="nuds:date | nuds:dateRange | nuds:denomination | nuds:material | nuds:objectType | nuds:manufacture"/>
	</xsl:template>

	<xsl:template match="nuds:physDesc">
		<xsl:apply-templates select="nuds:weight | nuds:diameter | nuds:axis"/>
	</xsl:template>

	<xsl:template match="nuds:adminDesc">
		<xsl:apply-templates select="nuds:identifier"/>
	</xsl:template>

	<xsl:template
		match="nuds:date | nuds:denomination | nuds:material | nuds:weight | nuds:diameter | nuds:axis | nuds:identifier | nuds:objectType | nuds:manufacture">
		<_object>
			<label>
				<xsl:value-of select="numishare:regularize_node(local-name(), $lang)"/>
			</label>
			<value>
				<xsl:value-of select="normalize-space(.)"/>
			</value>
		</_object>
	</xsl:template>

	<xsl:template match="nuds:dateRange">
		<_object>
			<label>
				<xsl:value-of select="numishare:regularize_node('date', $lang)"/>
			</label>
			<value>
				<xsl:value-of select="normalize-space(nuds:fromDate)"/>
				<xsl:text> - </xsl:text>
				<xsl:value-of select="normalize-space(nuds:toDate)"/>
			</value>
		</_object>
	</xsl:template>

	<xsl:template match="nuds:obverse | nuds:reverse">
		<xsl:value-of select="numishare:regularize_node(local-name(), $lang)"/>
		<xsl:text>: </xsl:text>
		<xsl:if test="nuds:legend">
			<xsl:value-of select="nuds:legend"/>
		</xsl:if>
		<xsl:if test="nuds:legend and nuds:type">
			<xsl:text> - </xsl:text>
		</xsl:if>
		<xsl:if test="nuds:type">
			<xsl:value-of select="nuds:type/nuds:description[@xml:lang = $lang]"/>
		</xsl:if>
		<xsl:if test="not(position() = last())">
			<xsl:text>\n</xsl:text>
		</xsl:if>
	</xsl:template>

	<!-- generate sequence -->
	<xsl:template name="sequences">
		<sequences>
			<_array>
				<_object>
					<__id>
						<xsl:value-of select="concat($manifestUri, '/sequence/default')"/>
					</__id>
					<__type>sc:Sequence</__type>
					<label>Default sequence</label>
					<canvases>
						<_array>
							<xsl:choose>
								<!-- apply METS templates for NUDS records of physical coins -->
								<xsl:when test="$recordType = 'physical'">
									<xsl:variable name="sizes" as="element()*">
										<sizes>
											<obverse>
												<xsl:apply-templates select="doc('input:obverse-json')/*"/>
											</obverse>
											<reverse>
												<xsl:apply-templates select="doc('input:reverse-json')/*"/>
											</reverse>
										</sizes>
									</xsl:variable>

									<xsl:apply-templates select="descendant::mets:file[@USE = 'iiif']">
										<xsl:with-param name="sizes" select="$sizes"/>
									</xsl:apply-templates>
								</xsl:when>
								<!-- otherwise, apply templates on SPARQL results -->
								<xsl:otherwise>
									<xsl:apply-templates select="doc('input:sparqlResults')//res:result"/>
								</xsl:otherwise>
							</xsl:choose>
						</_array>

					</canvases>
					<viewingHint>individuals</viewingHint>
				</_object>
			</_array>
		</sequences>
	</xsl:template>

	<!-- create canvases out of mets:files -->
	<xsl:template match="mets:file">
		<xsl:param name="sizes"/>
		<xsl:variable name="side" select="parent::mets:fileGrp/@USE"/>

		<_object>
			<__id>
				<xsl:value-of select="concat($manifestUri, '/canvas/', $side)"/>
			</__id>
			<__type>sc:Canvas</__type>
			<label>
				<xsl:value-of select="numishare:regularize_node($side, $lang)"/>
			</label>
			<thumbnail>
				<_object>
					<__id>
						<xsl:value-of select="parent::mets:fileGrp/mets:file[@USE = 'thumbnail']/mets:FLocat/@xlink:href"/>
					</__id>
					<__type>dctypes:Image</__type>
					<format>image/jpeg</format>
					<height>175</height>
					<width>175</width>
				</_object>
			</thumbnail>
			<height>
				<xsl:value-of select="$sizes/*[name() = $side]/height"/>
			</height>
			<width>
				<xsl:value-of select="$sizes/*[name() = $side]/width"/>
			</width>
			<images>
				<_array>
					<xsl:apply-templates select="mets:FLocat">
						<xsl:with-param name="side" select="$side"/>
						<xsl:with-param name="sizes" select="$sizes"/>
					</xsl:apply-templates>
				</_array>
			</images>
		</_object>
	</xsl:template>

	<xsl:template match="mets:FLocat">
		<xsl:param name="sizes"/>
		<xsl:param name="side"/>

		<_object>
			<__id>
				<xsl:value-of select="concat($manifestUri, '/annotation/', $side)"/>
			</__id>
			<__type>oa:Annotation</__type>
			<motivation>sc:painting</motivation>
			<on>
				<xsl:value-of select="concat($manifestUri, '/canvas/', $side)"/>
			</on>
			<resource>
				<_object>
					<__id>
						<xsl:value-of select="concat(@xlink:href, '/full/full/0/default.jpg')"/>
					</__id>
					<__type>dctypes:Image</__type>
					<format>image/jpeg</format>
					<height>
						<xsl:value-of select="$sizes/*[name() = $side]/height"/>
					</height>
					<width>
						<xsl:value-of select="$sizes/*[name() = $side]/width"/>
					</width>
					<service>
						<_object>
							<__context>http://iiif.io/api/image/2/context.json</__context>
							<__id>
								<xsl:value-of select="@xlink:href"/>
							</__id>
							<profile>http://iiif.io/api/image/2/level2.json</profile>
						</_object>
					</service>
				</_object>
			</resource>
		</_object>
	</xsl:template>

	<!-- generate dimsension variable for image sizes, derived from the image API JSON -->
	<xsl:template match="json[@type = 'object']">
		<height>
			<xsl:value-of select="height"/>
		</height>
		<width>
			<xsl:value-of select="width"/>
		</width>
	</xsl:template>

	<!-- generate canvases from SPARQL results for coin type manifests -->
	<xsl:template match="res:result">
		<_object>
			<__id>
				<xsl:value-of select="res:binding[@name='object']/res:uri"/>
			</__id>
			<__type>sc:Canvas</__type>
			<label>
				<xsl:value-of select="res:binding[@name = 'title']/res:literal"/>
			</label>
			<!--<thumbnail>
				<_object>
					<__id>
						<xsl:value-of select="parent::mets:fileGrp/mets:file[@USE = 'thumbnail']/mets:FLocat/@xlink:href"/>
					</__id>
					<__type>dctypes:Image</__type>
					<format>image/jpeg</format>
					<height>175</height>
					<width>175</width>
				</_object>
			</thumbnail>-->
			<!--<height>
				<xsl:value-of select="$sizes/*[name()=$side]/height"/>
			</height>
			<width>
				<xsl:value-of select="$sizes/*[name()=$side]/width"/>
			</width>-->
			<images>
				<_array>
					<xsl:choose>
						<xsl:when test="res:binding[@name='comService']">
							<xsl:apply-templates select="res:binding[@name='comService']"/>
						</xsl:when>
						<xsl:when test="res:binding[@name='obvService'] and res:binding[@name='revService']">
							<xsl:apply-templates select="res:binding[@name='obvService']"/>
							<xsl:apply-templates select="res:binding[@name='revService']"/>
						</xsl:when>
					</xsl:choose>
					<!--<xsl:apply-templates select="mets:FLocat">
						<xsl:with-param name="side" select="$side"/>
						<xsl:with-param name="sizes" select="$sizes"/>
					</xsl:apply-templates>-->
				</_array>
			</images>
		</_object>
	</xsl:template>
	
	<!-- generate images for IIIF service URIs -->
	<xsl:template match="res:binding[@name='comService']|res:binding[@name='obvService']|res:binding[@name='revService']">
		<_object>
			<__id>
				<xsl:value-of select="res:uri"/>
			</__id>
			<__type>oa:Annotation</__type>
			<motivation>sc:painting</motivation>
			<on>
				<xsl:value-of select="parent::node()/res:binding[@name='object']/res:uri"/>
			</on>
			<resource>
				<_object>
					<__id>
						<xsl:value-of select="concat(res:uri, '/full/full/0/default.jpg')"/>
					</__id>
					<__type>dctypes:Image</__type>
					<format>image/jpeg</format>
					<!--<height>
						<xsl:value-of select="$sizes/*[name() = $side]/height"/>
					</height>
					<width>
						<xsl:value-of select="$sizes/*[name() = $side]/width"/>
					</width>-->
					<service>
						<_object>
							<__context>http://iiif.io/api/image/2/context.json</__context>
							<__id>
								<xsl:value-of select="res:uri"/>
							</__id>
							<profile>http://iiif.io/api/image/2/level2.json</profile>
						</_object>
					</service>
				</_object>
			</resource>
		</_object>
	</xsl:template>

	<!-- ******* FUNCTIONS ******** -->
	<xsl:template name="numishare:evaluateDatatype">
		<xsl:param name="val"/>

		<xsl:choose>
			<!-- metadata fields must be a string -->
			<xsl:when test="ancestor::metadata">
				<xsl:value-of select="concat('&#x022;', replace($val, '&#x022;', '\\&#x022;'), '&#x022;')"/>
			</xsl:when>
			<xsl:when test="number($val)">
				<xsl:value-of select="$val"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="concat('&#x022;', replace($val, '&#x022;', '\\&#x022;'), '&#x022;')"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

</xsl:stylesheet>