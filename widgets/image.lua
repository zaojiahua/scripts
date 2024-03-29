local Widget = require "widgets/widget"

Image = Class(Widget, function(self, atlas, tex)
    Widget._ctor(self, "Image")
    
    self.inst.entity:AddImageWidget()
    
    assert( ( atlas == nil and tex == nil ) or ( atlas ~= nil and tex ~= nil ) )

    if atlas and tex then
		self:SetTexture(atlas, tex)
    end
end)

function Image:__tostring()
	return string.format("%s - %s:%s", self.name, self.atlas or "", self.texture or "")
end

function Image:SetAlphaRange(min, max)
	self.inst.ImageWidget:SetAlphaRange(min, max)
end

function Image:SetTexture(atlas, tex)
    assert( atlas ~= nil )
    assert( tex ~= nil )

	self.atlas = resolvefilepath(atlas)
	self.texture = tex
	--print(atlas, tex)
    self.inst.ImageWidget:SetTexture(self.atlas, self.texture)

	-- changing the texture may have changed our metrics
	self.inst.UITransform:UpdateTransform()
end

function Image:SetMouseOverTexture(atlas, tex)
	self.atlas = resolvefilepath(atlas)
	self.mouseovertex = tex
end

function Image:SetDisabledTexture(atlas, tex)
	self.atlas = resolvefilepath(atlas)
	self.disabledtex = tex
end

function Image:SetSize(w,h)
    if type(w) == "number" then
        self.inst.ImageWidget:SetSize(w,h)
    else
        self.inst.ImageWidget:SetSize(w[1],w[2])
    end
end

function Image:GetSize()
    local w, h = self.inst.ImageWidget:GetSize()
    return w, h
end

function Image:ScaleToSize(w, h)
	local w0, h0 = self.inst.ImageWidget:GetSize()
	local scalex = w / w0
	local scaley = h / h0
	self:SetScale(scalex, scaley, 1)
end

function Image:SetTint(r,g,b,a)
    self.inst.ImageWidget:SetTint(r,g,b,a)
end

function Image:SetVRegPoint(anchor)
    self.inst.ImageWidget:SetVAnchor(anchor)
end

function Image:SetHRegPoint(anchor)
    self.inst.ImageWidget:SetHAnchor(anchor)
end

function Image:OnMouseOver()
	--print("Image:OnMouseOver", self)
	if self.enabled and self.mouseovertex then
		self.inst.ImageWidget:SetTexture(self.atlas, self.mouseovertex)
	end
	Widget.OnMouseOver( self )
end

function Image:OnMouseOut()
	--print("Image:OnMouseOut", self)
	if self.enabled and self.mouseovertex then
		self.inst.ImageWidget:SetTexture(self.atlas, self.texture)
	end
	Widget.OnMouseOut( self )
end

function Image:OnEnable()
    if self.mouse_over_self then
		self:OnMouseOver()
	else
		self.inst.ImageWidget:SetTexture(self.atlas, self.texture)
	end
end

function Image:OnDisable()
	self.inst.ImageWidget:SetTexture(self.atlas, self.disabledtex)
end

function Image:SetEffect(filename)
	self.inst.ImageWidget:SetEffect(filename)
end

return Image
