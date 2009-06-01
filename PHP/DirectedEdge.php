<?php

require_once('HTTP/Request2.php');

class DirectedEdgeResource
{
    private $base;

    public function __construct($base)
    {
        $this->base = $base;
    }
    
    public function path($path = "")
    {
        return $this->base . '/' . urlencode($path);
    }

    public function get($path = "")
    {
        $request = new HTTP_Request2($this->path($path));
        $response = $request->send();
        return $response->getBody();
    }

    public function __toString()
    {
        return $this->base;
    }
}

class DirectedEdgeDatabase
{
    private $resource;

    public function __construct($name, $password, $protocol = 'http')
    {
        $host = $_ENV['DIRECTEDEDGE_HOST'];

        if(!$host)
        {
            $host = 'webservices.directededge.com';
        }

        $base = "$protocol://$name:$password@$host/api/v1/$name";

        $this->resource = new DirectedEdgeResource($base);
    }

    public function resource()
    {
        return $this->resource;
    }

    public function import($fileName)
    {

    }
}

class DirectedEdgeItem
{
    private $database;
    private $id;
    private $resource;
    private $links = array();
    private $tags = array();
    private $properties = array();
    private $cached = false;

    public function __construct($database, $id)
    {
        $this->database = $database;
        $this->resource = new DirectedEdgeResource($database->resource()->path($id));
        $this->id = $id;
    }

    public function name()
    {
        return $this->id;
    }

    public function links()
    {
        $this->read();
        return $this->links;
    }

    public function tags()
    {
        $this->read();
        return $this->tags;
    }

    public function properties()
    {
        $this->read();
        return $this->properties;
    }

    public function property($name)
    {
        $this->read();
        return $this->properties[$name];
    }

    public function setProperty($name, $value)
    {
        $this->properties[$name] = $value;
    }

    public function clearProperty($name)
    {
        unset($this->properties[$name]);
    }

    public function destroy()
    {

    }

    public function linkTo($other, $weight = 0)
    {
        $this->links[$other] = $weight;
    }

    public function unlinkFrom($other)
    {
        unset($this->links[$other]);
    }

    public function weightFor($other)
    {
        return $this->links[$other];
    }

    public function addTag($tag)
    {
        $this->tags[] = $tag;
    }

    public function removeTag($tag)
    {
        function filter($item) { return $item == $tag; }
        $this->tags = array_filter($this->tags, filter);
    }

    private function read()
    {
        if($this->cached)
        {
            return;
        }

        $content = $this->resource->get();
        $document = new DOMDocument();
        $document->loadXML($content);

        $linkNodes = $document->getElementsByTagName('link');

        for($i = 0; $i < $linkNodes->length; $i++)
        {
            $link = $linkNodes->item($i)->textContent;

            # Don't overwrite links that the user has created.

            if(!isset($this->links[$link]))
            {
                $weight = $linkNodes->item($i)->attributes->getNamedItem('weight');
                $this->links[$link] = $weight ? $weight : 0;
            }
        }

        $this->tags =
            $this->getValuesByTagName($document, 'tag', null, $this->tags);
        $this->properties =
            $this->getValuesByTagName($document, 'property', 'name', $this->properties);

        $this->cached = true;
    }

    /**
     * @param XMLDocument The document to search in.
     * @param string The element name to extract.
     * @param string The name of the attribute to use as the key.  If none, then a normal (non-hash)
     * array is created.
     * @param array Existing values.  Will not be overwritten if they exits.
     */

    private function getValuesByTagName($document, $element, $attribute = null, $values = array())
    {
        $nodes = $document->getElementsByTagName($element);

        for($i = 0; $i < $nodes->length; $i++)
        {
            if($attribute)
            {
                $key = $nodes->item($i)->attributes->getNamedItem($attribute)->textContent;

                if(!isset($values[$key]))
                {
                    $values[$key] = $nodes->item($i)->textContent;
                }
            }
            else
            {
                $values[] = $nodes->item($i)->textContent;
            }
        }

        return $values;
    }
}

class DirectedEdgeExporter
{

}

$database = new DirectedEdgeDatabase('testdb', 'test');
$item = new DirectedEdgeItem($database, 'Socrates');
print_r($item->links());
print_r($item->tags());
print_r($item->properties());
?>